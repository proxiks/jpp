package jpp


import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Version information.
const (
	Version     = "1.0.0"
	Name        = "J++ Language Library"
	Standard    = "J++23"
	GoVersion   = "1.21+"
)

// Target architecture
type Target int

const (
	TargetX86_64 Target = iota
	TargetX86
	TargetARM64
	TargetARM32
	TargetRISCV64
	TargetRISCV32
	TargetWASM32
	TargetNative // Host architecture
)

func (t Target) String() string {
	switch t {
	case TargetX86_64:
		return "x86-64"
	case TargetX86:
		return "x86"
	case TargetARM64:
		return "arm64"
	case TargetARM32:
		return "arm32"
	case TargetRISCV64:
		return "riscv64"
	case TargetRISCV32:
		return "riscv32"
	case TargetWASM32:
		return "wasm32"
	case TargetNative:
		return "native"
	default:
		return "unknown"
	}
}

func (t Target) Bits() int {
	switch t {
	case TargetX86_64, TargetARM64, TargetRISCV64:
		return 64
	case TargetX86, TargetARM32, TargetRISCV32, TargetWASM32:
		return 32
	default:
		return 64
	}
}

func (t Target) Assembler() string {
	switch t {
	case TargetX86_64, TargetX86:
		return "as"
	case TargetARM64:
		return "aarch64-linux-gnu-as"
	case TargetARM32:
		return "arm-linux-gnueabihf-as"
	case TargetRISCV64:
		return "riscv64-linux-gnu-as"
	case TargetRISCV32:
		return "riscv32-linux-gnu-as"
	default:
		return "as"
	}
}

// Optimization level
type OptLevel int

const (
	OptO0 OptLevel = iota // No optimization
	OptO1                 // Basic
	OptO2                 // Standard
	OptO3                 // Aggressive
	OptOs                 // Size
	OptOfast              // Fast (non-standard)
)

func (o OptLevel) String() string {
	switch o {
	case OptO0:
		return "O0"
	case OptO1:
		return "O1"
	case OptO2:
		return "O2"
	case OptO3:
		return "O3"
	case OptOs:
		return "Os"
	case OptOfast:
		return "Ofast"
	default:
		return "O0"
	}
}

// Assembly syntax
type AsmSyntax int

const (
	SyntaxIntel AsmSyntax = iota
	SyntaxATT
)

func (s AsmSyntax) String() string {
	if s == SyntaxIntel {
		return "intel"
	}
	return "att"
}

// Compiler configuration
type Config struct {
	Target       Target
	OptLevel     OptLevel
	Syntax       AsmSyntax
	Debug        bool
	Freestanding bool
	Verbose      bool
	Silent       bool
	ShowTime     bool
	EmitAST      bool
	EmitTokens   bool
	EmitIR       bool
	EmitASM      bool
	SaveTemps    bool
	OutputFile   string
	IncludePaths []string
	DefineMacros map[string]string
	LinkLibs     []string
}

// Default configuration
func DefaultConfig() Config {
	return Config{
		Target:       TargetNative,
		OptLevel:     OptO0,
		Syntax:       SyntaxIntel,
		Debug:        false,
		Freestanding: false,
		Verbose:      false,
		Silent:       false,
		ShowTime:     false,
		EmitAST:      false,
		EmitTokens:   false,
		EmitIR:       false,
		EmitASM:      false,
		SaveTemps:    false,
		DefineMacros: make(map[string]string),
	}
}

// ============================================================================
// COMPILATION RESULT
// ============================================================================

type CompileResult struct {
	Success      bool
	OutputFile   string
	AssemblyFile string
	ObjectFile   string
	Errors       []CompileError
	Warnings     []CompileError
	Times        CompileTimes
	AST          *ASTNode
	Tokens       []Token
}

type CompileError struct {
	Line    int
	Column  int
	File    string
	Message string
	Code    string
	Fatal   bool
}

func (e CompileError) Error() string {
	if e.Fatal {
		return fmt.Sprintf("%s:%d:%d: fatal error: %s", e.File, e.Line, e.Column, e.Message)
	}
	return fmt.Sprintf("%s:%d:%d: error: %s", e.File, e.Line, e.Column, e.Message)
}

func (e CompileError) Warning() string {
	return fmt.Sprintf("%s:%d:%d: warning: %s", e.File, e.Line, e.Column, e.Message)
}

type CompileTimes struct {
	Lex       float64
	Parse     float64
	Semantic  float64
	Codegen   float64
	Assemble  float64
	Link      float64
	Total     float64
}

func (t CompileTimes) String() string {
	return fmt.Sprintf(
		"Lex: %.3fs, Parse: %.3fs, Semantic: %.3fs, CodeGen: %.3fs, Assemble: %.3fs, Link: %.3fs, Total: %.3fs",
		t.Lex, t.Parse, t.Semantic, t.Codegen, t.Assemble, t.Link, t.Total,
	)
}

// ============================================================================
// MAIN COMPILER API
// ============================================================================

// CompileFile compiles a J++ source file
func CompileFile(filename string, cfg Config) (*CompileResult, error) {
	source, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("cannot read file %s: %w", filename, err)
	}
	return CompileSource(filename, string(source), cfg)
}

// CompileSource compiles J++ source code from string
func CompileSource(filename, source string, cfg Config) (*CompileResult, error) {
	result := &CompileResult{
		Errors:   make([]CompileError, 0),
		Warnings: make([]CompileError, 0),
	}

	// Step 1: Lexical Analysis
	lexer := NewLexer(filename, source)
	tokens, err := lexer.Tokenize()
	if err != nil {
		result.Errors = append(result.Errors, CompileError{
			Line:    lexer.Line(),
			Column:  lexer.Column(),
			File:    filename,
			Message: err.Error(),
			Fatal:   true,
		})
		return result, err
	}
	result.Tokens = tokens

	if cfg.EmitTokens {
		dumpTokens(tokens, filename+".tokens")
	}

	// Step 2: Parsing
	parser := NewParser(tokens, filename)
	ast, err := parser.Parse()
	if err != nil {
		result.Errors = append(result.Errors, CompileError{
			Line:    parser.Line(),
			Column:  parser.Column(),
			File:    filename,
			Message: err.Error(),
			Fatal:   true,
		})
		return result, err
	}
	result.AST = ast

	if cfg.EmitAST {
		ast.DumpToFile(filename + ".ast")
	}

	// Step 3: Semantic Analysis
	semantic := NewSemanticAnalyzer()
	semantic.SetWarningsAll(cfg.Verbose)
	semantic.SetWarningsError(cfg.Debug)
	
	errCount := semantic.Analyze(ast)
	if errCount > 0 {
		for _, err := range semantic.Errors() {
			result.Errors = append(result.Errors, CompileError{
				Line:    err.Line,
				Column:  err.Column,
				File:    err.File,
				Message: err.Message,
				Fatal:   true,
			})
		}
		return result, fmt.Errorf("semantic analysis failed with %d errors", errCount)
	}

	// Step 4: Code Generation (Direct Assembly!)
	codegen := NewCodeGen(cfg)
	assembly, err := codegen.Generate(ast)
	if err != nil {
		result.Errors = append(result.Errors, CompileError{
			Message: err.Error(),
			Fatal:   true,
		})
		return result, err
	}

	if cfg.EmitASM || cfg.EmitIR {
		asmFile := cfg.OutputFile + ".s"
		if cfg.EmitIR {
			asmFile = cfg.OutputFile + ".ir.s"
		}
		os.WriteFile(asmFile, []byte(assembly), 0644)
		result.AssemblyFile = asmFile
	}

	// Step 5: Assemble
	if cfg.EmitASM {
		result.Success = true
		return result, nil
	}

	objFile := cfg.OutputFile + ".o"
	if err := assemble(assembly, objFile, cfg); err != nil {
		result.Errors = append(result.Errors, CompileError{
			Message: fmt.Sprintf("assembly failed: %v", err),
			Fatal:   true,
		})
		return result, err
	}
	result.ObjectFile = objFile

	if cfg.EmitIR {
		result.Success = true
		return result, nil
	}

	// Step 6: Link
	outputFile := cfg.OutputFile
	if outputFile == "" {
		outputFile = strings.TrimSuffix(filename, filepath.Ext(filename))
	}
	
	if err := link(objFile, outputFile, cfg); err != nil {
		result.Errors = append(result.Errors, CompileError{
			Message: fmt.Sprintf("linking failed: %v", err),
			Fatal:   true,
		})
		return result, err
	}

	result.OutputFile = outputFile
	result.Success = true
	return result, nil
}

// Assemble assembly code to object file
func assemble(assembly, output string, cfg Config) error {
	// Write assembly to temp file
	asmFile := output + ".tmp.s"
	if err := os.WriteFile(asmFile, []byte(assembly), 0644); err != nil {
		return err
	}
	defer os.Remove(asmFile)

	// Run assembler
	as := cfg.Target.Assembler()
	args := []string{"-o", output, asmFile}
	
	if cfg.Target.Bits() == 32 {
		args = append([]string{"--32"}, args...)
	} else {
		args = append([]string{"--64"}, args...)
	}

	cmd := execCommand(as, args...)
	if cfg.Verbose {
		fmt.Printf("[jpp] as %s\n", strings.Join(args, " "))
	}
	
	output_bytes, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("assembler error: %s\n%s", err, string(output_bytes))
	}
	return nil
}

// Link object file to executable
func link(objFile, output string, cfg Config) error {
	var cmd *execCmd
	
	if cfg.Freestanding {
		// Use ld directly for freestanding
		args := []string{"-o", output, objFile}
		if cfg.Target.Bits() == 64 {
			args = append([]string{"-m", "elf_x86_64"}, args...)
		} else {
			args = append([]string{"-m", "elf_i386"}, args...)
		}
		cmd = execCommand("ld", args...)
	} else {
		// Use gcc for normal linking with C runtime
		args := []string{"-o", output, objFile}
		if cfg.Target.Bits() == 32 {
			args = append([]string{"-m32"}, args...)
		} else {
			args = append([]string{"-m64"}, args...)
		}
		if cfg.Debug {
			args = append(args, "-g")
		}
		for _, lib := range cfg.LinkLibs {
			args = append(args, "-l"+lib)
		}
		cmd = execCommand("gcc", args...)
	}

	if cfg.Verbose {
		fmt.Printf("[jpp] %s\n", strings.Join(cmd.Args, " "))
	}

	output_bytes, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("linker error: %s\n%s", err, string(output_bytes))
	}
	return nil
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

func dumpTokens(tokens []Token, filename string) error {
	var sb strings.Builder
	sb.WriteString("=== J++ TOKENS ===\n\n")
	for _, tok := range tokens {
		sb.WriteString(fmt.Sprintf("[%3d:%3d] %-20s '%s'\n",
			tok.Line, tok.Column, tok.Type.String(), tok.Lexeme))
	}
	return os.WriteFile(filename, []byte(sb.String()), 0644)
}

// execCommand is a helper to create exec.Cmd (avoiding import issues)
type execCmd struct {
	Args []string
}

func execCommand(name string, arg ...string) *execCmd {
	return &execCmd{Args: append([]string{name}, arg...)}
}

// ============================================================================
// REPL (Read-Eval-Print Loop)
// ============================================================================

type REPL struct {
	vm       *VM
	scanner  *bufio.Scanner
	history  []string
	prompt   string
}

func NewREPL() *REPL {
	return &REPL{
		vm:      NewVM(),
		scanner: bufio.NewScanner(os.Stdin),
		prompt:  "jpp> ",
	}
}

func (r *REPL) SetPrompt(prompt string) {
	r.prompt = prompt
}

func (r *REPL) Run() error {
	fmt.Printf("J++ %s Interactive Shell\n", Version)
	fmt.Println("Type 'exit' to quit, 'help' for commands")
	fmt.Println()

	for {
		fmt.Print(r.prompt)
		if !r.scanner.Scan() {
			break
		}

		line := strings.TrimSpace(r.scanner.Text())
		if line == "" {
			continue
		}

		r.history = append(r.history, line)

		switch line {
		case "exit", "quit":
			fmt.Println("Goodbye!")
			return nil
		case "help":
			r.printHelp()
		case "version":
			fmt.Printf("J++ %s (%s)\n", Version, Standard)
		case "clear":
			fmt.Print("\033[H\033[2J")
		default:
			if err := r.eval(line); err != nil {
				fmt.Printf("Error: %v\n", err)
			}
		}
	}

	return r.scanner.Err()
}

func (r *REPL) eval(code string) error {
	// Wrap in main function if not already
	if !strings.Contains(code, "int main") {
		code = fmt.Sprintf("int main(){\n%s\nreturn 0;\n}", code)
	}

	result, err := CompileSource("<repl>", code, DefaultConfig())
	if err != nil {
		return err
	}

	if !result.Success {
		for _, e := range result.Errors {
			fmt.Println(e.Error())
		}
		return fmt.Errorf("compilation failed")
	}

	// Execute with VM
	return r.vm.ExecuteString(code)
}

func (r *REPL) printHelp() {
	fmt.Println("Commands:")
	fmt.Println("  help     - Show this help")
	fmt.Println("  version  - Show version")
	fmt.Println("  clear    - Clear screen")
	fmt.Println("  exit     - Exit REPL")
	fmt.Println()
	fmt.Println("Example:")
	fmt.Println("  printel(\"Hello World\")")
	fmt.Println("  int x = 10")
	fmt.Println("  for(int i=0; i<5; i++) printel(\"%d\", i)")
}

// ============================================================================
// FORMATTER
// ============================================================================

type Formatter struct {
	indentSize int
	useTabs    bool
}

func NewFormatter() *Formatter {
	return &Formatter{indentSize: 4, useTabs: false}
}

func (f *Formatter) Format(source string) (string, error) {
	lexer := NewLexer("<format>", source)
	tokens, err := lexer.Tokenize()
	if err != nil {
		return "", err
	}

	var sb strings.Builder
	indent := 0
	prevLine := 0

	for i, tok := range tokens {
		if tok.Line != prevLine {
			// New line
			if sb.Len() > 0 {
				sb.WriteString("\n")
			}
			// Add indentation
			for j := 0; j < indent; j++ {
				if f.useTabs {
					sb.WriteString("\t")
				} else {
					for k := 0; k < f.indentSize; k++ {
						sb.WriteString(" ")
					}
				}
			}
			prevLine = tok.Line
		} else if i > 0 {
			// Same line, add space if needed
			if needsSpace(tokens[i-1], tok) {
				sb.WriteString(" ")
			}
		}

		sb.WriteString(tok.Lexeme)

		// Adjust indentation
		if tok.Type == TokenLBrace {
			indent++
		} else if tok.Type == TokenRBrace {
			indent--
			if indent < 0 {
				indent = 0
			}
		}
	}

	return sb.String(), nil
}

func needsSpace(prev, curr Token) bool {
	// Don't add space after opening paren or before closing
	if prev.Type == TokenLParen || curr.Type == TokenRParen {
		return false
	}
	if prev.Type == TokenLBracket || curr.Type == TokenRBracket {
		return false
	}
	// Don't add space before semicolon or comma
	if curr.Type == TokenSemicolon || curr.Type == TokenComma {
		return false
	}
	// Don't add space after unary operators
	if prev.Type == TokenInc || prev.Type == TokenDec {
		return false
	}
	return true
}

// ============================================================================
// LINTER
// ============================================================================

type Linter struct {
	rules []LintRule
}

type LintRule struct {
	Name        string
	Description string
	Severity    string // error, warning, info
	Check       func(*ASTNode) []LintIssue
}

type LintIssue struct {
	Line     int
	Column   int
	Message  string
	Severity string
	Rule     string
}

func NewLinter() *Linter {
	return &Linter{
		rules: []LintRule{
			{
				Name:        "unused-variable",
				Description: "Check for unused variables",
				Severity:    "warning",
				Check:       checkUnusedVariables,
			},
			{
				Name:        "uninitialized-variable",
				Description: "Check for uninitialized variables",
				Severity:    "error",
				Check:       checkUninitializedVariables,
			},
			{
				Name:        "return-missing",
				Description: "Check for missing return statements",
				Severity:    "error",
				Check:       checkMissingReturns,
			},
			{
				Name:        "dead-code",
				Description: "Check for unreachable code",
				Severity:    "warning",
				Check:       checkDeadCode,
			},
		},
	}
}

func (l *Linter) Lint(ast *ASTNode) []LintIssue {
	var issues []LintIssue
	for _, rule := range l.rules {
		issues = append(issues, rule.Check(ast)...)
	}
	return issues
}

func checkUnusedVariables(node *ASTNode) []LintIssue {
	var issues []LintIssue
	// Implementation would traverse AST and find unused variables
	return issues
}

func checkUninitializedVariables(node *ASTNode) []LintIssue {
	var issues []LintIssue
	return issues
}

func checkMissingReturns(node *ASTNode) []LintIssue {
	var issues []LintIssue
	return issues
}

func checkDeadCode(node *ASTNode) []LintIssue {
	var issues []LintIssue
	return issues
}

// ============================================================================
// DOCUMENTATION GENERATOR
// ============================================================================

type DocGenerator struct {
	outputDir string
}

func NewDocGenerator(outputDir string) *DocGenerator {
	return &DocGenerator{outputDir: outputDir}
}

func (d *DocGenerator) Generate(ast *ASTNode) error {
	// Generate HTML/Markdown documentation from AST
	return nil
}

// ============================================================================
// PACKAGE MANAGER (JPPM - J++ Package Manager)
// ============================================================================

type Package struct {
	Name        string
	Version     string
	Author      string
	Description string
	License     string
	Repository  string
	Dependencies []string
	Files       []string
}

type PackageManager struct {
	registryURL string
	localPath   string
}

func NewPackageManager() *PackageManager {
	home, _ := os.UserHomeDir()
	return &PackageManager{
		registryURL: "https://jpp-registry.dev",
		localPath:   filepath.Join(home, ".jpp", "packages"),
	}
}

func (pm *PackageManager) Install(pkgName string) error {
	fmt.Printf("Installing %s...\n", pkgName)
	return nil
}

func (pm *PackageManager) Remove(pkgName string) error {
	fmt.Printf("Removing %s...\n", pkgName)
	return nil
}

func (pm *PackageManager) List() ([]Package, error) {
	return []Package{}, nil
}

func (pm *PackageManager) Search(query string) ([]Package, error) {
	return []Package{}, nil
}

// ============================================================================
// TEST RUNNER
// ============================================================================

type TestRunner struct {
	verbose bool
}

func NewTestRunner() *TestRunner {
	return &TestRunner{verbose: false}
}

type TestResult struct {
	Name     string
	Passed   bool
	Duration float64
	Error    error
}

func (tr *TestRunner) RunFile(filename string) ([]TestResult, error) {
	source, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return tr.RunSource(string(source))
}

func (tr *TestRunner) RunSource(source string) ([]TestResult, error) {
	// Parse test functions (functions starting with "test_")
	// Run each and collect results
	return []TestResult{}, nil
}

// ============================================================================
// BENCHMARK
// ============================================================================

type Benchmark struct {
	name     string
	iterations int
}

func NewBenchmark(name string) *Benchmark {
	return &Benchmark{name: name, iterations: 1000000}
}

func (b *Benchmark) Run(fn func()) BenchmarkResult {
	start := now()
	for i := 0; i < b.iterations; i++ {
		fn()
	}
	elapsed := since(start)
	
	return BenchmarkResult{
		Name:       b.name,
		Iterations: b.iterations,
		Duration:   elapsed,
		PerOp:      elapsed / float64(b.iterations),
	}
}

type BenchmarkResult struct {
	Name       string
	Iterations int
	Duration   float64 // seconds
	PerOp      float64 // seconds per operation
}

func (r BenchmarkResult) String() string {
	return fmt.Sprintf("%s: %d ops, %.3fs total, %.6fs/op",
		r.Name, r.Iterations, r.Duration, r.PerOp)
}

// Helper time functions
func now() float64 {
	// Simplified - use actual time in real implementation
	return 0
}

func since(start float64) float64 {
	return 0
}