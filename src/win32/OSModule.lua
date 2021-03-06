-- test_OSModule.lua
--
--

local ffi = require("ffi");

local libraryloader = require("core_libraryloader_l1_1_1");
local errorhandling = require("core_errorhandling_l1_1_1");

ffi.cdef[[
typedef struct {
	void *	Handle;
} OSModuleHandle;
]]
local OSModuleHandle = ffi.typeof("OSModuleHandle");
local OSModuleHandle_mt = {
	__gc = function(self)
		print("GC: OSModuleHandle");
		local status = libraryloader.FreeLibrary(self.Handle);
	end,

	__index = {
		getProcAddress = function(self, procName)
			local addr = libraryloader.GetProcAddress(self.Handle, procName);
			return addr;
		end,

	},
}
ffi.metatype(OSModuleHandle, OSModuleHandle_mt);



local OSModule = {}
setmetatable(OSModule,{
	__call = function(self, ...)
		return self:create(...);
	end,
})

--[[
	Metatable for instances of the OSModule 
--]]
local OSModule_mt = {
	__index = function(self, key)
		-- if it's something that can be found
		-- in our internal functions, then just
		-- return that
		if OSModule[key] then
			return OSModule[key];
		end

		-- Otherwise, try to find it as a function
		-- that is actually in the loaded module
		local ffitype = ffi.C[key];
		if not ffitype then
			return false, "function prototype not found"
		end

		-- could use reflect at this point to ensure it is
		-- actually a pointer to a function
		--local refct = reflect.typeof(ffitype);
		--if refct.what ~= "func" then
		--	return false, "not a function"
		--end

		-- turn the function information into a function pointer
		local proc = self.Handle:getProcAddress(key);
		if not proc then
			return nil, "function not found in module"
		end
		
print("OSModule.__index, getProcAddress: ", proc)

		ffitype = ffi.typeof("$ *", ffitype);
		local castval = ffi.cast(ffitype, proc);
		
		return castval;
	end,
}



function OSModule.init(self, handle)
	local obj = {
		Handle = OSModuleHandle(handle);
	};

	setmetatable(obj, OSModule_mt);

	return obj;
end

function OSModule.create(self, name, flags)
	flags = flags or 0

	local handle = libraryloader.LoadLibraryExA(name, nil, flags);
	
	if handle == nil then
		return nil, errorhandling.GetLastError();
	end

	return self:init(handle);
end

function OSModule.getNativeHandle(self)
	return self.Handle.Handle
end

function OSModule.getProcAddress(self, procName)
	local addr = libraryloader.GetProcAddress(self:getNativeHandle(), procName);
	if not addr then
		return nil, errorhandling.GetLastError();
	end

	return addr;
end


return OSModule
