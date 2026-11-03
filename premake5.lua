-- Jolt Physics as a static library. Mirrors Jolt/Jolt.cmake and Build/CMakeLists.txt with their default options,
-- except:
--  - no GPU compute backends (DX12, Vulkan, Metal): they need dxc to compile Jolt/Shaders/*.hlsl at build time.
--    CPU compute (JPH_USE_CPU_COMPUTE, the default) is kept, so hair simulation still runs.
--  - C++ exceptions and RTTI stay on (upstream turns them off), so the library matches the projects that link it.
--  - warnings aren't errors (upstream: /Wall /WX).
--
-- Projects that use Jolt call UseJolt(): its headers change layout with these defines, so every project including
-- them must see the same ones as the library (a mismatch gives link errors or silent ABI breaks).

local root = _SCRIPT_DIR

JoltIncludeDir = root

-- The library's public defines and instruction set, for this project and everything that includes Jolt
local function JoltPublicSettings()
    defines
    {
        "JPH_OBJECT_STREAM",    -- ENABLE_OBJECT_STREAM
        "JPH_USE_CPU_COMPUTE",  -- JPH_USE_CPU_COMPUTE
        -- USE_SSE4_1 ... USE_FMADD; with /arch:AVX2 below
        "JPH_USE_AVX2",
        "JPH_USE_AVX",
        "JPH_USE_SSE4_1",
        "JPH_USE_SSE4_2",
        "JPH_USE_LZCNT",
        "JPH_USE_TZCNT",
        "JPH_USE_F16C",
        "JPH_USE_FMADD",
    }

    filter { "system:windows", "architecture:x86_64" }
        buildoptions { "/arch:AVX2" }

    filter "configurations:Debug"
        defines { "JPH_DEBUG" }

    -- DEBUG_RENDERER_IN_DEBUG_AND_RELEASE, PROFILER_IN_DEBUG_AND_RELEASE, FLOATING_POINT_EXCEPTIONS_ENABLED
    filter "configurations:Debug or configurations:Release"
        defines { "JPH_DEBUG_RENDERER", "JPH_PROFILE_ENABLED", "JPH_FLOATING_POINT_EXCEPTIONS_ENABLED" }

    filter {}
end

-- For a project that includes Jolt's headers and links the library
function UseJolt()
    includedirs { JoltIncludeDir }
    links { "Jolt" }
    JoltPublicSettings()
end

project "Jolt"
    kind "StaticLib"
    language "C++"
    cppdialect "C++17"
    staticruntime "on"

    targetdir("%{wks.location}/bin/" .. outputdir .. "/%{prj.name}")
    objdir("%{wks.location}/bin-int/" .. outputdir .. "/%{prj.name}")

    files
    {
        root .. "/Jolt/**.h",
        root .. "/Jolt/**.inl",
        root .. "/Jolt/**.cpp",
        root .. "/Jolt/**.hlsl", -- the compute shaders, run on the CPU through Compute/CPU (not compiled here)
        root .. "/Jolt/Jolt.natvis",
    }

    removefiles
    {
        root .. "/Jolt/Compute/DX12/**",
        root .. "/Jolt/Compute/VK/**",
        root .. "/Jolt/Compute/MTL/**",
    }

    -- Shaders are included by the CPU compute wrappers as headers, never compiled on their own
    filter "files:**.hlsl"
        buildaction "None"
    filter {}

    includedirs { root }

    JoltPublicSettings()

    -- Upstream: /Zc:__cplusplus /fp:except- /Zc:inline, and /fp:fast unless CROSS_PLATFORM_DETERMINISTIC
    buildoptions { "/Zc:__cplusplus", "/fp:except-", "/Zc:inline" }
    floatingpoint "Fast"

    filter "system:windows"
        systemversion "latest"

    filter "configurations:Debug"
        runtime "Debug"
        symbols "on"

    filter "configurations:Release or configurations:Dist"
        runtime "Release"
        optimize "speed"
        symbols "on"
        defines { "NDEBUG" } -- as CMake's Release
        -- OVERRIDE_CXX_FLAGS: no buffer security checks, function-level linking, intrinsics
        buildoptions { "/GS-", "/Gy", "/Oi" }
    filter {}
