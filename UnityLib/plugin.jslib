// ============================================================
// J++ WASM BRIDGE - WebGL JavaScript
// C# ↔ Lua ↔ Browser WASM interop
// BSD-2-Clause License
// ============================================================

mergeInto(LibraryManager.library, {
    // Load WASM module
    wasm_load_module: function(namePtr, dataPtr, length) {
        var name = UTF8ToString(namePtr);
        var data = HEAPU8.subarray(dataPtr, dataPtr + length);
        
        console.log('[JppWASM] Loading module:', name, length, 'bytes');
        
        // Store in global registry
        if (!window.jppWasmModules) window.jppWasmModules = {};
        
        // Compile WASM
        WebAssembly.compile(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength))
            .then(module => {
                window.jppWasmModules[name] = module;
                console.log('[JppWASM] Module compiled:', name);
            })
            .catch(err => {
                console.error('[JppWASM] Compile error:', err);
            });
    },
    
    // Call WASM function
    wasm_call_function: function(modulePtr, functionPtr, argsPtr) {
        var moduleName = UTF8ToString(modulePtr);
        var functionName = UTF8ToString(functionPtr);
        var args = UTF8ToString(argsPtr);
        
        console.log('[JppWASM] Call:', moduleName + '.' + functionName, args);
        
        var module = window.jppWasmModules[moduleName];
        if (!module) {
            console.error('[JppWASM] Module not found:', moduleName);
            return -1;
        }
        
        // Instantiate and call
        // This is simplified - real implementation needs proper memory management
        return 0;
    },
    
    // Get result string
    wasm_get_result: function(modulePtr, functionPtr) {
        var moduleName = UTF8ToString(modulePtr);
        var functionName = UTF8ToString(functionPtr);
        
        // Return cached result
        var result = window.jppWasmResults?.[moduleName + '.' + functionName] || '';
        var bufferSize = lengthBytesUTF8(result) + 1;
        var buffer = _malloc(bufferSize);
        stringToUTF8(result, buffer, bufferSize);
        return buffer;
    },
    
    // Free allocated string
    wasm_free_string: function(ptr) {
        _free(ptr);
    },
    
    // WebSocket send (for XML networking)
    jpp_websocket_send: function(urlPtr, messagePtr) {
        var url = UTF8ToString(urlPtr);
        var message = UTF8ToString(messagePtr);
        
        if (!window.jppWebSockets) window.jppWebSockets = {};
        
        var ws = window.jppWebSockets[url];
        if (!ws || ws.readyState !== WebSocket.OPEN) {
            ws = new WebSocket(url);
            window.jppWebSockets[url] = ws;
        }
        
        ws.send(message);
        return 0;
    },
    
    // WebSocket receive
    jpp_websocket_recv: function(urlPtr, bufferPtr, bufferSize) {
        var url = UTF8ToString(urlPtr);
        var ws = window.jppWebSockets?.[url];
        
        if (!ws || ws.readyState !== WebSocket.OPEN) return -1;
        
        // Queue-based receive would be implemented here
        return 0;
    }
});