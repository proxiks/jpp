package jpp

import (
	"strings"
	"testing"
)

// ============================================================================
// LEXER TESTS
// ============================================================================

func TestLexerBasics(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []TokenType
	}{
		{
			name:     "hello world",
			input:    `printel("Hello World");`,
			expected: []TokenType{TokenPrintel, TokenLParen, TokenStringLiteral, TokenRParen, TokenSemicolon, TokenEOF},
		},
		{
			name:     "variable declaration",
			input:    `int x = 42;`,
			expected: []TokenType{TokenInt, TokenIdentifier, TokenAssign, TokenIntLiteral, TokenSemicolon, TokenEOF},
		},
		{
			name:     "function definition",
			input:    `int add(int a, int b) { return a + b; }`,
			expected: []TokenType{TokenInt, TokenIdentifier, TokenLParen, TokenInt, TokenIdentifier, TokenComma, TokenInt, TokenIdentifier, TokenRParen, TokenLBrace, TokenReturn, TokenIdentifier, TokenPlus, TokenIdentifier, TokenSemicolon, TokenRBrace, TokenEOF},
		},
		{
			name:     "for loop",
			input:    `for(int i = 0; i < 10; i++) { printel("%d", i); }`,
			expected: []TokenType{TokenFor, TokenLParen, TokenInt, TokenIdentifier, TokenAssign, TokenIntLiteral, TokenSemicolon, TokenIdentifier, TokenLt, TokenIntLiteral, TokenSemicolon, TokenIdentifier, TokenInc, TokenRParen, TokenLBrace, TokenPrintel, TokenLParen, TokenStringLiteral, TokenComma, TokenIdentifier, TokenRParen, TokenSemicolon, TokenRBrace, TokenEOF},
		},
		{
			name:     "if else",
			input:    `if(x > 0) { return 1; } else { return 0; }`,
			expected: []TokenType{TokenIf, TokenLParen, TokenIdentifier, TokenGt, TokenIntLiteral, TokenRParen, TokenLBrace, TokenReturn, TokenIntLiteral, TokenSemicolon, TokenRBrace, TokenElse, TokenLBrace, TokenReturn, TokenIntLiteral, TokenSemicolon, TokenRBrace, TokenEOF},
		},
		{
			name:     "comments",
			input:    `// single line comment\nint x = 5; /* multi-line\ncomment */ int y = 10;`,
			expected: []TokenType{TokenInt, TokenIdentifier, TokenAssign, TokenIntLiteral, TokenSemicolon, TokenInt, TokenIdentifier, TokenAssign, TokenIntLiteral, TokenSemicolon, TokenEOF},
		},
		{
			name:     "operators",
			input:    `a + b - c * d / e % f && g || h & i | j ^ k << l >> m`,
			expected: []TokenType{TokenIdentifier, TokenPlus, TokenIdentifier, TokenMinus, TokenIdentifier, TokenStar, TokenIdentifier, TokenSlash, TokenIdentifier, TokenPercent, TokenIdentifier, TokenLogicalAnd, TokenIdentifier, TokenLogicalOr, TokenIdentifier, TokenBitAnd, TokenIdentifier, TokenBitOr, TokenIdentifier, TokenBitXor, TokenIdentifier, TokenLShift, TokenIdentifier, TokenRShift, TokenEOF},
		},
		{
			name:     "compound assignment",
			input:    `x += 1; y -= 2; z *= 3; w /= 4;`,
			expected: []TokenType{TokenIdentifier, TokenPlusAssign, TokenIntLiteral, TokenSemicolon, TokenIdentifier, TokenMinusAssign, TokenIntLiteral, TokenSemicolon, TokenIdentifier, TokenStarAssign, TokenIntLiteral, TokenSemicolon, TokenIdentifier, TokenSlashAssign, TokenIntLiteral, TokenSemicolon, TokenEOF},
		},
		{
			name:     "preprocessor",
			input:    `#include <ios++>\n#define MAX 100\n#ifdef DEBUG\n#endif`,
			expected: []TokenType{TokenHashInclude, TokenStringLiteral, TokenHashDefine, TokenIdentifier, TokenIntLiteral, TokenHashIfdef, TokenIdentifier, TokenHashEndif, TokenEOF},
		},
		{
			name:     "data types",
			input:    `void bool char short int long float double string very long double`,
			expected: []TokenType{TokenVoid, TokenBool, TokenChar, TokenShort, TokenInt, TokenLong, TokenFloat, TokenDouble, TokenString, TokenVery, TokenLong, TokenDouble, TokenEOF},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lexer := NewLexer("test.jpp", tt.input)
			tokens, err := lexer.Tokenize()
			if err != nil {
				t.Fatalf("lexer error: %v", err)
			}

			if len(tokens) != len(tt.expected) {
				t.Fatalf("token count mismatch: got %d, want %d", len(tokens), len(tt.expected))
			}

			for i, expected := range tt.expected {
				if tokens[i].Type != expected {
					t.Errorf("token %d: got %v, want %v", i, tokens[i].Type, expected)
				}
			}
		})
	}
}

func TestLexerLiterals(t *testing.T) {
	tests := []struct {
		name          string
		input         string
		expectedType  TokenType
		expectedValue string
	}{
		{"integer", "42", TokenIntLiteral, "42"},
		{"negative int", "-42", TokenMinus, "-"},
		{"float", "3.14", TokenFloatLiteral, "3.14"},
		{"scientific", "1.5e10", TokenFloatLiteral, "1.5e10"},
		{"string", `"hello"`, TokenStringLiteral, `"hello"`},
		{"char", "'a'", TokenCharLiteral, "'a'"},
		{"true", "true", TokenBoolLiteral, "true"},
		{"false", "false", TokenBoolLiteral, "false"},
		{"null", "null", TokenNull, "null"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lexer := NewLexer("test.jpp", tt.input)
			tokens, _ := lexer.Tokenize()
			if len(tokens) < 1 {
				t.Fatal("no tokens generated")
			}
			if tokens[0].Type != tt.expectedType {
				t.Errorf("got %v, want %v", tokens[0].Type, tt.expectedType)
			}
			if tokens[0].Lexeme != tt.expectedValue {
				t.Errorf("got %v, want %v", tokens[0].Lexeme, tt.expectedValue)
			}
		})
	}
}

func TestLexerStringEscapes(t *testing.T) {
	input := `"hello\\nworld\\ttab"`
	lexer := NewLexer("test.jpp", input)
	tokens, _ := lexer.Tokenize()
	
	if tokens[0].Type != TokenStringLiteral {
		t.Errorf("expected string literal, got %v", tokens[0].Type)
	}
	
	if !strings.Contains(tokens[0].StrVal, "hello") {
		t.Errorf("string value incorrect: %v", tokens[0].StrVal)
	}
}

func TestLexerPosition(t *testing.T) {
	input := `int x = 5;
float y = 3.14;`
	lexer := NewLexer("test.jpp", input)
	tokens, _ := lexer.Tokenize()
	
	// Check line numbers
	if tokens[0].Line != 1 {
		t.Errorf("first token line: got %d, want 1", tokens[0].Line)
	}
	
	// Find float token (should be on line 2)
	for _, tok := range tokens {
		if tok.Type == TokenFloat {
			if tok.Line != 2 {
				t.Errorf("float token line: got %d, want 2", tok.Line)
			}
		}
	}
}

func BenchmarkLexer(b *testing.B) {
	input := `
		int main() {
			for(int i = 0; i < 1000; i++) {
				printel("Hello %d\n", i);
			}
			return 0;
		}
	`
	
	for i := 0; i < b.N; i++ {
		lexer := NewLexer("bench.jpp", input)
		lexer.Tokenize()
	}
}

// ============================================================================
// VM TESTS
// ============================================================================

func TestVMBasics(t *testing.T) {
	vm := NewVM()
	
	// Test push and pop
	vm.push(VMValue{Type: VMInt, Int: 42})
	val := vm.pop()
	if val.Int != 42 {
		t.Errorf("push/pop failed: got %d, want 42", val.Int)
	}
	
	// Test arithmetic
	vm.push(VMValue{Type: VMInt, Int: 10})
	vm.push(VMValue{Type: VMInt, Int: 20})
	// Add would be: vm.executeInstruction(VMInstruction{Op: OP_ADD})
	
	vm.Reset()
}

func TestVMBuiltins(t *testing.T) {
	vm := NewVM()
	
	// Test printel
	result := vm.builtinPrintel(vm, []VMValue{
		{Type: VMString, Str: "Hello %s"},
		{Type: VMString, Str: "World"},
	})
	
	if result.Type != VMInt {
		t.Errorf("printel return type wrong: %v", result.Type)
	}
	
	// Test len
	result = vm.builtinLen(vm, []VMValue{
		{Type: VMString, Str: "hello"},
	})
	
	if result.Int != 5 {
		t.Errorf("len failed: got %d, want 5", result.Int)
	}
	
	// Test typeof
	result = vm.builtinTypeof(vm, []VMValue{
		{Type: VMInt, Int: 42},
	})
	
	if result.Str != "int" {
		t.Errorf("typeof failed: got %s, want int", result.Str)
	}
	
	// Test math
	result = vm.builtinSqrt(vm, []VMValue{
		{Type: VMInt, Int: 16},
	})
	
	if result.Float != 4.0 {
		t.Errorf("sqrt failed: got %f, want 4.0", result.Float)
	}
}

func TestVMValueConversions(t *testing.T) {
	v := VMValue{Type: VMInt, Int: 42}
	
	if v.ToInt() != 42 {
		t.Errorf("ToInt failed")
	}
	
	if v.ToFloat() != 42.0 {
		t.Errorf("ToFloat failed")
	}
	
	if !v.ToBool() {
		t.Errorf("ToBool failed")
	}
	
	v = VMValue{Type: VMString, Str: "hello"}
	if v.ToInt() != 0 {
		t.Errorf("string ToInt should be 0")
	}
	if !v.ToBool() {
		t.Errorf("non-empty string should be true")
	}
}

func TestVMBytecode(t *testing.T) {
	vm := NewVM()
	
	// Simple program: push 10, push 20, add, exit
	code := []VMInstruction{
		{Op: OP_LOADI, Arg1: 10},
		{Op: OP_LOADI, Arg1: 20},
		{Op: OP_ADD},
		{Op: OP_EXIT, Arg1: 0},
	}
	
	vm.Load(code)
	exitCode := vm.Execute()
	
	if exitCode != 0 {
		t.Errorf("exit code: got %d, want 0", exitCode)
	}
	
	// Check stack top
	if vm.RSP != 1 {
		t.Errorf("stack size: got %d, want 1", vm.RSP)
	}
	
	if vm.Stack[0].Int != 30 {
		t.Errorf("result: got %d, want 30", vm.Stack[0].Int)
	}
}

func TestVMState(t *testing.T) {
	vm := NewVM()
	vm.push(VMValue{Type: VMInt, Int: 1})
	vm.push(VMValue{Type: VMInt, Int: 2})
	vm.push(VMValue{Type: VMInt, Int: 3})
	
	state := vm.DumpState()
	if !strings.Contains(state, "RSP: 3") {
		t.Errorf("state dump missing RSP")
	}
	if !strings.Contains(state, "Stack (top 10)") {
		t.Errorf("state dump missing stack")
	}
}

func BenchmarkVMExecute(b *testing.B) {
	vm := NewVM()
	code := []VMInstruction{
		{Op: OP_LOADI, Arg1: 1},
		{Op: OP_LOADI, Arg1: 2},
		{Op: OP_ADD},
		{Op: OP_EXIT, Arg1: 0},
	}
	
	for i := 0; i < b.N; i++ {
		vm.Reset()
		vm.Load(code)
		vm.Execute()
	}
}

// ============================================================================
// COMPILER TESTS
// ============================================================================

func TestCompileConfig(t *testing.T) {
	cfg := DefaultConfig()
	
	if cfg.Target != TargetNative {
		t.Errorf("default target wrong")
	}
	
	if cfg.OptLevel != OptO0 {
		t.Errorf("default opt level wrong")
	}
	
	if cfg.Syntax != SyntaxIntel {
		t.Errorf("default syntax wrong")
	}
}

func TestTargetString(t *testing.T) {
	tests := []struct {
		target Target
		want   string
		bits   int
	}{
		{TargetX86_64, "x86-64", 64},
		{TargetX86, "x86", 32},
		{TargetARM64, "arm64", 64},
		{TargetARM32, "arm32", 32},
		{TargetRISCV64, "riscv64", 64},
		{TargetRISCV32, "riscv32", 32},
		{TargetWASM32, "wasm32", 32},
	}
	
	for _, tt := range tests {
		if tt.target.String() != tt.want {
			t.Errorf("Target(%d).String() = %v, want %v", tt.target, tt.target.String(), tt.want)
		}
		if tt.target.Bits() != tt.bits {
			t.Errorf("Target(%d).Bits() = %d, want %d", tt.target, tt.target.Bits(), tt.bits)
		}
	}
}

func TestOptLevelString(t *testing.T) {
	tests := []struct {
		level OptLevel
		want  string
	}{
		{OptO0, "O0"},
		{OptO1, "O1"},
		{OptO2, "O2"},
		{OptO3, "O3"},
		{OptOs, "Os"},
		{OptOfast, "Ofast"},
	}
	
	for _, tt := range tests {
		if tt.level.String() != tt.want {
			t.Errorf("OptLevel(%d).String() = %v, want %v", tt.level, tt.level.String(), tt.want)
		}
	}
}

// ============================================================================
// FORMATTER TESTS
// ============================================================================

func TestFormatter(t *testing.T) {
	formatter := NewFormatter()
	
	input := `int main(){int x=5;return x;}`
	expected := `int main() {
    int x = 5;
    return x;
}`
	
	result, err := formatter.Format(input)
	if err != nil {
		t.Fatalf("format error: %v", err)
	}
	
	if !strings.Contains(result, "int main()") {
		t.Errorf("formatting failed: %v", result)
	}
}

// ============================================================================
// BENCHMARK TESTS
// ============================================================================

func BenchmarkLexerLarge(b *testing.B) {
	// Generate large source file
	var sb strings.Builder
	for i := 0; i < 1000; i++ {
		sb.WriteString("int x = ")
		sb.WriteString(string(rune('0' + i%10)))
		sb.WriteString(";\n")
	}
	input := sb.String()
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		lexer := NewLexer("bench.jpp", input)
		lexer.Tokenize()
	}
}

func BenchmarkVMPushPop(b *testing.B) {
	vm := NewVM()
	val := VMValue{Type: VMInt, Int: 42}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		vm.push(val)
		vm.pop()
	}
}

func BenchmarkBuiltinPrintel(b *testing.B) {
	vm := NewVM()
	args := []VMValue{
		{Type: VMString, Str: "Hello %s"},
		{Type: VMString, Str: "World"},
	}
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		vm.builtinPrintel(vm, args)
	}
}

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

func TestIntegrationHelloWorld(t *testing.T) {
	code := `
		#include <ios++>
		int main() {
			printel("Hello World\n");
			return 0;
		}
	`
	
	lexer := NewLexer("hello.jpp", code)
	tokens, err := lexer.Tokenize()
	if err != nil {
		t.Fatalf("lexer error: %v", err)
	}
	
	// Verify tokens contain expected keywords
	hasPrintel := false
	hasString := false
	for _, tok := range tokens {
		if tok.Type == TokenPrintel {
			hasPrintel = true
		}
		if tok.Type == TokenStringLiteral && strings.Contains(tok.StrVal, "Hello World") {
			hasString = true
		}
	}
	
	if !hasPrintel {
		t.Error("missing printel token")
	}
	if !hasString {
		t.Error("missing hello world string")
	}
}

func TestIntegrationArithmetic(t *testing.T) {
	code := `
		int result = 10 + 20 * 3 - 5 / 2;
		return result;
	`
	
	lexer := NewLexer("math.jpp", code)
	tokens, err := lexer.Tokenize()
	if err != nil {
		t.Fatalf("lexer error: %v", err)
	}
	
	// Verify operator sequence
	expectedOps := []TokenType{TokenPlus, TokenStar, TokenMinus, TokenSlash}
	opIdx := 0
	for _, tok := range tokens {
		if tok.Type == TokenPlus || tok.Type == TokenStar || tok.Type == TokenMinus || tok.Type == TokenSlash {
			if opIdx < len(expectedOps) && tok.Type != expectedOps[opIdx] {
				t.Errorf("operator %d: got %v, want %v", opIdx, tok.Type, expectedOps[opIdx])
			}
			opIdx++
		}
	}
}

func TestIntegrationFullProgram(t *testing.T) {
	code := `
		#include <ios++>
		#include <math>
		
		int factorial(int n) {
			if(n <= 1) {
				return 1;
			}
			return n * factorial(n - 1);
		}
		
		int main() {
			int num = 5;
			int result = factorial(num);
			printel("Factorial of %d is %d\n", num, result);
			return 0;
		}
	`
	
	lexer := NewLexer("factorial.jpp", code)
	tokens, err := lexer.Tokenize()
	if err != nil {
		t.Fatalf("lexer error: %v", err)
	}
	
	// Check for function definition
	hasFunc := false
	hasReturn := false
	hasIf := false
	for _, tok := range tokens {
		if tok.Type == TokenIdentifier && tok.Lexeme == "factorial" {
			hasFunc = true
		}
		if tok.Type == TokenReturn {
			hasReturn = true
		}
		if tok.Type == TokenIf {
			hasIf = true
		}
	}
	
	if !hasFunc {
		t.Error("missing factorial function")
	}
	if !hasReturn {
		t.Error("missing return statements")
	}
	if !hasIf {
		t.Error("missing if statement")
	}
}