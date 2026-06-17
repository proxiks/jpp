-- ============================================================
-- J++ PHYSICS ENGINE - Lua
-- Unity Physics, Graphics, Shaders
-- BSD-2-Clause License
-- ============================================================

local physics = {}
local ffi = require("ffi")

-- FFI bindings to C physics library
ffi.cdef[[
    typedef struct { double x, y, z; } vec3;
    typedef struct { double m[9]; } mat3;
    typedef struct { double m[16]; } mat4;
    
    void phys_raycast(vec3 origin, vec3 direction, double maxDist, void* hit);
    void phys_add_force(void* rigidbody, vec3 force, int mode);
    void phys_set_velocity(void* rigidbody, vec3 velocity);
    vec3 phys_get_velocity(void* rigidbody);
    void phys_gravity(vec3 g);
    
    void math_fft(double* in_r, double* in_i, double* out_r, double* out_i, int n);
    void math_mat_mul(double* a, double* b, double* c, int m, int n, int p);
    void math_mat_inv(double* a, double* inv, int n);
    double math_mat_det(double* a, int n);
]]

-- WASM bridge
local wasm = require("wasm_bridge")

-- ============================================================
-- VECTOR MATH (MATLAB-style)
-- ============================================================

function vec3.new(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0}
end

function vec3.__add(a, b)
    return vec3.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

function vec3.__sub(a, b)
    return vec3.new(a.x - b.x, a.y - b.y, a.z - b.z)
end

function vec3.__mul(a, b)
    if type(b) == "number" then
        return vec3.new(a.x * b, a.y * b, a.z * b)
    end
    -- dot product
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function vec3.__div(a, b)
    if type(b) == "number" then
        return vec3.new(a.x / b, a.y / b, a.z / b)
    end
    error("Cannot divide vector by vector")
end

function vec3.cross(a, b)
    return vec3.new(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

function vec3.magnitude(v)
    return math.sqrt(v.x^2 + v.y^2 + v.z^2)
end

function vec3.normalize(v)
    local mag = vec3.magnitude(v)
    if mag == 0 then return vec3.new(0, 0, 0) end
    return v / mag
end

setmetatable(vec3, {__call = function(_, x, y, z) return vec3.new(x, y, z) end})

-- ============================================================
-- MATRIX MATH
-- ============================================================

local matrix = {}

function matrix.new(rows, cols, data)
    local m = {
        rows = rows,
        cols = cols,
        data = data or {}
    }
    return m
end

function matrix.zeros(rows, cols)
    local data = {}
    for i = 1, rows * cols do data[i] = 0 end
    return matrix.new(rows, cols, data)
end

function matrix.ones(rows, cols)
    local data = {}
    for i = 1, rows * cols do data[i] = 1 end
    return matrix.new(rows, cols, data)
end

function matrix.eye(n)
    local m = matrix.zeros(n, n)
    for i = 1, n do m.data[(i-1)*n + i] = 1 end
    return m
end

-- Element-wise operations
function matrix.ewmul(a, b)
    assert(a.rows == b.rows and a.cols == b.cols)
    local result = matrix.zeros(a.rows, a.cols)
    for i = 1, a.rows * a.cols do
        result.data[i] = a.data[i] * b.data[i]
    end
    return result
end

function matrix.ewdiv(a, b)
    assert(a.rows == b.rows and a.cols == b.cols)
    local result = matrix.zeros(a.rows, a.cols)
    for i = 1, a.rows * a.cols do
        result.data[i] = a.data[i] / b.data[i]
    end
    return result
end

function matrix.ewpow(a, p)
    local result = matrix.zeros(a.rows, a.cols)
    for i = 1, a.rows * a.cols do
        result.data[i] = a.data[i] ^ p
    end
    return result
end

-- Matrix multiplication
function matrix.mul(a, b)
    assert(a.cols == b.rows)
    local result = matrix.zeros(a.rows, b.cols)
    
    -- Use C library for performance
    local a_ptr = ffi.new("double[?]", a.rows * a.cols)
    local b_ptr = ffi.new("double[?]", b.rows * b.cols)
    local c_ptr = ffi.new("double[?]", a.rows * b.cols)
    
    for i = 1, a.rows * a.cols do a_ptr[i-1] = a.data[i] end
    for i = 1, b.rows * b.cols do b_ptr[i-1] = b.data[i] end
    
    ffi.C.math_mat_mul(a_ptr, b_ptr, c_ptr, a.rows, a.cols, b.cols)
    
    for i = 1, a.rows * b.cols do result.data[i] = c_ptr[i-1] end
    return result
end

-- Transpose
function matrix.transpose(m)
    local result = matrix.zeros(m.cols, m.rows)
    for i = 1, m.rows do
        for j = 1, m.cols do
            result.data[(j-1)*m.rows + i] = m.data[(i-1)*m.cols + j]
        end
    end
    return result
end

-- ============================================================
-- UNITY PHYSICS WRAPPERS
-- ============================================================

physics.Rigidbody = {}
physics.Rigidbody.__index = physics.Rigidbody

function physics.Rigidbody.new(unity_ptr)
    local rb = {ptr = unity_ptr}
    setmetatable(rb, physics.Rigidbody)
    return rb
end

function physics.Rigidbody:AddForce(force, mode)
    mode = mode or "Force"
    local f = ffi.new("vec3", {force.x, force.y, force.z})
    local mode_int = mode == "Force" and 0 or mode == "Impulse" and 1 or 0
    ffi.C.phys_add_force(self.ptr, f, mode_int)
end

function physics.Rigidbody:MovePosition(pos)
    -- WASM call to Unity
    wasm.call("Rigidbody_MovePosition", self.ptr, pos.x, pos.y, pos.z)
end

function physics.Rigidbody:SetVelocity(v)
    local vel = ffi.new("vec3", {v.x, v.y, v.z})
    ffi.C.phys_set_velocity(self.ptr, vel)
end

function physics.Rigidbody:GetVelocity()
    local v = ffi.C.phys_get_velocity(self.ptr)
    return vec3(v.x, v.y, v.z)
end

-- ============================================================
-- RAYCASTING
-- ============================================================

function physics.Raycast(origin, direction, maxDistance)
    maxDistance = maxDistance or math.huge
    local o = ffi.new("vec3", {origin.x, origin.y, origin.z})
    local d = ffi.new("vec3", {direction.x, direction.y, direction.z})
    local hit = ffi.new("void*[1]")
    
    ffi.C.phys_raycast(o, d, maxDistance, hit)
    
    if hit[0] ~= nil then
        return true, {
            collider = hit[0],
            point = vec3(0, 0, 0), -- filled by C
            normal = vec3(0, 1, 0),
            distance = 0
        }
    end
    return false, nil
end

-- ============================================================
-- FFT (Signal Processing)
-- ============================================================

function physics.FFT(signal)
    local n = #signal
    local in_r = ffi.new("double[?]", n)
    local in_i = ffi.new("double[?]", n)
    local out_r = ffi.new("double[?]", n)
    local out_i = ffi.new("double[?]", n)
    
    for i = 1, n do
        in_r[i-1] = signal[i]
        in_i[i-1] = 0
    end
    
    ffi.C.math_fft(in_r, in_i, out_r, out_i, n)
    
    local result = {}
    for i = 1, n do
        result[i] = {real = out_r[i-1], imag = out_i[i-1]}
    end
    return result
end

function physics.IFFT(spectrum)
    local n = #spectrum
    local in_r = ffi.new("double[?]", n)
    local in_i = ffi.new("double[?]", n)
    local out_r = ffi.new("double[?]", n)
    local out_i = ffi.new("double[?]", n)
    
    for i = 1, n do
        in_r[i-1] = spectrum[i].real
        in_i[i-1] = spectrum[i].imag
    end
    
    ffi.C.math_ifft(in_r, in_i, out_r, out_i, n)
    
    local result = {}
    for i = 1, n do
        result[i] = out_r[i-1]
    end
    return result
end

-- ============================================================
-- PLASMA PHYSICS (Elenosperia)
-- ============================================================

physics.plasma = {}

function physics.plasma.init(temperature, pressure, ionization)
    return {
        temperature = temperature or 5000,
        pressure = pressure or 101325,
        ionization = ionization or 0.95,
        active = true
    }
end

function physics.plasma.conductivity(p)
    -- Saha equation approximation
    local T = p.temperature
    local n = p.ionization
    return n * math.sqrt(T) * 1e4
end

function physics.plasma.reaction(plasma, iron, water)
    -- Elenosperia reaction simulation
    local result = {
        h2_yield = 0,
        o2_yield = 0,
        feo_yield = 0,
        efficiency = 0,
        data = {}
    }
    
    -- Faraday's law: m = (M * I * t) / (n * F)
    local F = 96485.33212 -- Faraday constant
    local M_fe = 55.845
    local M_h2o = 18.015
    
    -- Simulate reaction
    for t = 0, 3600, 0.1 do
        local I = 1.5 -- Amps
        local m_h2 = (M_h2o * I * t) / (2 * F)
        result.h2_yield = m_h2
        
        table.insert(result.data, {
            time = t,
            temp = plasma.temperature,
            h2 = m_h2
        })
    end
    
    result.efficiency = result.h2_yield / 1000 -- theoretical max
    return result
end

-- ============================================================
-- SHADER GENERATION
-- ============================================================

physics.shader = {}

function physics.shader.generate(name, properties, vertex, fragment)
    local shader = {
        name = name,
        properties = properties or {},
        subshaders = {{
            passes = {{
                cgprogram = {
                    vertex = vertex,
                    fragment = fragment
                }
            }}
        }}
    }
    return shader
end

function physics.shader.toHLSL(shader)
    local code = "Shader \"" .. shader.name .. "\" {\n"
    code = code .. "    Properties {\n"
    for k, v in pairs(shader.properties) do
        code = code .. "        _" .. k .. " (\"" .. k .. "\", " .. v.type .. ") = " .. v.default .. "\n"
    end
    code = code .. "    }\n"
    code = code .. "    SubShader {\n"
    code = code .. "        Pass {\n"
    code = code .. "            CGPROGRAM\n"
    code = code .. "            #pragma vertex vert\n"
    code = code .. "            #pragma fragment frag\n"
    code = code .. shader.subshaders[1].passes[1].cgprogram.vertex .. "\n"
    code = code .. shader.subshaders[1].passes[1].cgprogram.fragment .. "\n"
    code = code .. "            ENDCG\n"
    code = code .. "        }\n"
    code = code .. "    }\n"
    code = code .. "}\n"
    return code
end

-- ============================================================
-- EXPORT
-- ============================================================

physics.vec3 = vec3
physics.matrix = matrix

return physics