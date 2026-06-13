import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
    console.log('J++ language extension activated');

    // Register document symbol provider
    const symbolProvider = vscode.languages.registerDocumentSymbolProvider(
        'jpp',
        new JppDocumentSymbolProvider()
    );

    // Register completion item provider
    const completionProvider = vscode.languages.registerCompletionItemProvider(
        'jpp',
        new JppCompletionItemProvider(),
        '.', ':', '>'
    );

    // Register hover provider
    const hoverProvider = vscode.languages.registerHoverProvider(
        'jpp',
        new JppHoverProvider()
    );

    context.subscriptions.push(symbolProvider, completionProvider, hoverProvider);
}

class JppDocumentSymbolProvider implements vscode.DocumentSymbolProvider {
    provideDocumentSymbols(document: vscode.TextDocument): vscode.DocumentSymbol[] {
        const symbols: vscode.DocumentSymbol[] = [];
        const text = document.getText();
        
        // Simple regex-based symbol extraction
        const functionRegex = /\\b(boot|kernel|aie_kernel|shim_kernel|int|void|bool|float|double|string)\\s+(\\w+)\\s*\\(/g;
        let match;
        while ((match = functionRegex.exec(text)) !== null) {
            const funcName = match[2];
            const range = new vscode.Range(
                document.positionAt(match.index),
                document.positionAt(match.index + match[0].length)
            );
            const symbol = new vscode.DocumentSymbol(
                funcName,
                match[1] + ' function',
                vscode.SymbolKind.Function,
                range,
                range
            );
            symbols.push(symbol);
        }

        return symbols;
    }
}

class JppCompletionItemProvider implements vscode.CompletionItemProvider {
    provideCompletionItems(): vscode.CompletionItem[] {
        const keywords = [
            'boot', 'kernel', 'aie_kernel', 'shim_kernel', 'dma_buffer', 'tile_coord',
            'xdna_l1', 'xdna_l2', 'xdna_l3', 'asm', 'volatile', 'const', 'struct',
            'union', 'enum', 'typedef', 'static', 'extern', 'inline', 'return', 'if',
            'else', 'for', 'while', 'do', 'goto', 'break', 'continue', 'switch', 'case',
            'default', 'sizeof', 'typeof', 'offsetof', 'true', 'false', 'void', 'bool',
            'char', 'short', 'int', 'long', 'float', 'double', 'unsigned', 'signed',
            'string', 'ptr', 'auto', 'register', 'NUL', 'NULL'
        ];

        const types = [
            'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64',
            'bfloat16', 'float32', 'float64', 'phys_addr', 'virt_addr', 'size_t',
            'ssize_t', 'off_t', 'pid_t', 'tid_t', 'FILE', 'dma_desc', 'xdna_dma',
            'xdna_stream_route', 'tile_coord', 'xdna_counter'
        ];

        const functions = [
            'printel', 'scanel', 'outb', 'outw', 'outl', 'inb', 'inw', 'inl',
            'memset', 'memcpy', 'memcmp', 'strlen', 'strcmp', 'strcpy',
            'fopen', 'fclose', 'fread', 'fwrite', 'fscanf', 'fprintf',
            'fgetc', 'fputc', 'fgets', 'fputs', 'fseek', 'ftell', 'rewind',
            'malloc', 'free', 'dma_alloc', 'hlt', 'halt'
        ];

        const items: vscode.CompletionItem[] = [];

        keywords.forEach(kw => {
            const item = new vscode.CompletionItem(kw, vscode.CompletionItemKind.Keyword);
            items.push(item);
        });

        types.forEach(type => {
            const item = new vscode.CompletionItem(type, vscode.CompletionItemKind.TypeParameter);
            items.push(item);
        });

        functions.forEach(func => {
            const item = new vscode.CompletionItem(func, vscode.CompletionItemKind.Function);
            items.push(item);
        });

        return items;
    }
}

class JppHoverProvider implements vscode.HoverProvider {
    provideHover(document: vscode.TextDocument, position: vscode.Position): vscode.Hover | undefined {
        const wordRange = document.getWordRangeAtPosition(position);
        if (!wordRange) return undefined;

        const word = document.getText(wordRange);

        const docs: { [key: string]: string } = {
            'printel': 'Print to stdout with newline. Usage: `printel("format", args...)`',
            'scanel': 'Read from stdin. Usage: `scanel("%d", variable)` (no & needed)',
            'boot': 'Boot section function attribute. Runs before main kernel.',
            'kernel': 'Kernel function attribute. Main kernel code.',
            'aie_kernel': 'AI Engine kernel attribute for XDNA NPU.',
            'dma_buffer': 'DMA buffer memory attribute. Must be contiguous and below 16MB.',
            'tile_coord': 'XDNA NPU tile coordinate type (x, y).',
            'xdna_l1': 'XDNA L1 memory attribute (64KB per AI Engine core).',
            'xdna_l2': 'XDNA L2 memory attribute (512KB per memory core).',
            'xdna_l3': 'XDNA L3 memory attribute (shared DDR/DRAM).',
            'asm': 'Inline assembly. Usage: `asm volatile ("instruction")`',
            'hlt': 'Halt CPU until next interrupt.',
            'halt': 'Halt system. Should never return.',
            'timer': 'Timer block. Usage: `timer(1 < 100) { ... }`',
            'NUL': 'Null pointer constant.',
            'NULL': 'Null pointer constant.',
        };

        if (docs[word]) {
            return new vscode.Hover(new vscode.MarkdownString(docs[word]));
        }

        return undefined;
    }
}
