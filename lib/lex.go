package jpp

import (
	"fmt"
	"strings"
	"unicode"
)


type TokenType int

const (
	// Literals
	TokenIntLiteral TokenType = iota
	TokenFloatLiteral
	TokenStringLiteral
	TokenCharLiteral
	TokenBoolLiteral

	// Identifiers
	TokenIdentifier

	// Keywords
	TokenIf
	TokenElse
	TokenFor
	TokenWhile
	TokenDo
	TokenSwitch
	TokenCase
	TokenDefault
	TokenBreak
	TokenContinue
	TokenReturn
	TokenGoto
	TokenStruct
	TokenUnion
	TokenEnum
	TokenTypedef
	TokenConst
	TokenVolatile
	TokenStatic
	TokenExtern
	TokenInline
	TokenRegister
	TokenAuto
	TokenSigned
	TokenUnsigned
	TokenVoid
	TokenBool
	TokenChar
	TokenShort
	TokenInt
	TokenLong
	TokenFloat
	TokenDouble
	TokenString
	TokenVery
	TokenTrue
	TokenFalse
	TokenNull
	TokenSizeof
	TokenTypeof

	// J++ specific keywords
	TokenPrintel
	TokenScanel
	TokenTimer

	// Operators
	TokenPlus
	TokenMinus
	TokenStar
	TokenSlash
	TokenPercent
	TokenInc
	TokenDec

	TokenAssign
	TokenPlusAssign
	TokenMinusAssign
	TokenStarAssign
	TokenSlashAssign
	TokenPercentAssign

	TokenEq
	TokenNe
	TokenLt
	TokenGt
	TokenLe
	TokenGe

	TokenLogicalAnd
	TokenLogicalOr
	TokenLogicalNot

	TokenBitAnd
	TokenBitOr
	TokenBitXor
	TokenBitNot
	TokenLShift
	TokenRShift

	TokenAndAssign
	TokenOrAssign
	TokenXorAssign
	TokenLShiftAssign
	TokenRShiftAssign

	// Punctuation
	TokenLParen
	TokenRParen
	TokenLBrace
	TokenRBrace
	TokenLBracket
	TokenRBracket
	TokenSemicolon
	TokenColon
	TokenComma
	TokenDot
	TokenArrow
	TokenEllipsis
	TokenQuestion

	// Preprocessor
	TokenHashInclude
	TokenHashDefine
	TokenHashIfdef
	TokenHashIfndef
	TokenHashIf
	TokenHashElif
	TokenHashElse
	TokenHashEndif
	TokenHashUndef
	TokenHashError
	TokenHashPragma
	TokenHashLine

	// Special
	TokenNewline
	TokenEOF
	TokenError
	TokenComment
	TokenWhitespace
)

func (t TokenType) String() string {
	names := []string{
		"INT_LITERAL", "FLOAT_LITERAL", "STRING_LITERAL", "CHAR_LITERAL", "BOOL_LITERAL",
		"IDENTIFIER",
		"IF", "ELSE", "FOR", "WHILE", "DO", "SWITCH", "CASE", "DEFAULT",
		"BREAK", "CONTINUE", "RETURN", "GOTO", "STRUCT", "UNION", "ENUM", "TYPEDEF",
		"CONST", "VOLATILE", "STATIC", "EXTERN", "INLINE", "REGISTER", "AUTO",
		"SIGNED", "UNSIGNED", "VOID", "BOOL", "CHAR", "SHORT", "INT", "LONG",
		"FLOAT", "DOUBLE", "STRING", "VERY", "TRUE", "FALSE", "NULL",
		"SIZEOF", "TYPEOF",
		"PRINTEL", "SCANEL", "TIMER",
		"PLUS", "MINUS", "STAR", "SLASH", "PERCENT", "INC", "DEC",
		"ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN", "PERCENT_ASSIGN",
		"EQ", "NE", "LT", "GT", "LE", "GE",
		"LOGICAL_AND", "LOGICAL_OR", "LOGICAL_NOT",
		"BIT_AND", "BIT_OR", "BIT_XOR", "BIT_NOT", "LSHIFT", "RSHIFT",
		"AND_ASSIGN", "OR_ASSIGN", "XOR_ASSIGN", "LSHIFT_ASSIGN", "RSHIFT_ASSIGN",
		"LPAREN", "RPAREN", "LBRACE", "RBRACE", "LBRACKET", "RBRACKET",
		"SEMICOLON", "COLON", "COMMA", "DOT", "ARROW", "ELLIPSIS", "QUESTION",
		"HASH_INCLUDE", "HASH_DEFINE", "HASH_IFDEF", "HASH_IFNDEF", "HASH_IF",
		"HASH_ELIF", "HASH_ELSE", "HASH_ENDIF", "HASH_UNDEF", "HASH_ERROR",
		"HASH_PRAGMA", "HASH_LINE",
		"NEWLINE", "EOF", "ERROR", "COMMENT", "WHITESPACE",
	}
	if int(t) < len(names) {
		return names[t]
	}
	return "UNKNOWN"
}

type Token struct {
	Type    TokenType
	Lexeme  string
	Line    int
	Column  int
	File    string
	IntVal  int64
	FloatVal float64
	StrVal  string
	BoolVal bool
	CharVal rune
}

type Lexer struct {
	input   string
	file    string
	pos     int
	line    int
	column  int
	tokens  []Token
	errors  []error
}

func NewLexer(file, input string) *Lexer {
	return &Lexer{
		input:  input,
		file:   file,
		pos:    0,
		line:   1,
		column: 1,
		tokens: make([]Token, 0),
		errors: make([]error, 0),
	}
}

func (l *Lexer) Line() int   { return l.line }
func (l *Lexer) Column() int { return l.column }

func (l *Lexer) peek() byte {
	if l.pos >= len(l.input) {
		return 0
	}
	return l.input[l.pos]
}

func (l *Lexer) peekNext() byte {
	if l.pos+1 >= len(l.input) {
		return 0
	}
	return l.input[l.pos+1]
}

func (l *Lexer) advance() byte {
	if l.pos >= len(l.input) {
		return 0
	}
	ch := l.input[l.pos]
	l.pos++
	if ch == '\\n' {
		l.line++
		l.column = 1
	} else {
		l.column++
	}
	return ch
}

func (l *Lexer) match(expected byte) bool {
	if l.peek() == expected {
		l.advance()
		return true
	}
	return false
}

func (l *Lexer) skipWhitespace() {
	for {
		ch := l.peek()
		if ch == ' ' || ch == '\\t' || ch == '\\r' || ch == '\\n' {
			l.advance()
		} else {
			break
		}
	}
}

func (l *Lexer) skipComment() {
	if l.peek() == '/' && l.peekNext() == '/' {
		// Single-line comment
		for l.peek() != '\\n' && l.peek() != 0 {
			l.advance()
		}
	} else if l.peek() == '/' && l.peekNext() == '*' {
		// Multi-line comment
		l.advance() // /
		l.advance() // *
		for !(l.peek() == '*' && l.peekNext() == '/') && l.peek() != 0 {
			l.advance()
		}
		if l.peek() != 0 {
			l.advance() // *
			l.advance() // /
		}
	}
}

func (l *Lexer) readString(quote byte) string {
	start := l.pos
	l.advance() // opening quote

	for l.peek() != quote && l.peek() != 0 {
		if l.peek() == '\\\\' {
			l.advance()
			l.advance()
		} else {
			l.advance()
		}
	}

	if l.peek() == quote {
		l.advance() // closing quote
	}

	return l.input[start:l.pos]
}

func (l *Lexer) readNumber() string {
	start := l.pos
	isFloat := false

	for unicode.IsDigit(rune(l.peek())) {
		l.advance()
	}

	if l.peek() == '.' && unicode.IsDigit(rune(l.peekNext())) {
		isFloat = true
		l.advance() // .
		for unicode.IsDigit(rune(l.peek())) {
			l.advance()
		}
	}

	if l.peek() == 'e' || l.peek() == 'E' {
		isFloat = true
		l.advance()
		if l.peek() == '+' || l.peek() == '-' {
			l.advance()
		}
		for unicode.IsDigit(rune(l.peek())) {
			l.advance()
		}
	}

	// Suffixes
	if l.peek() == 'f' || l.peek() == 'F' {
		l.advance()
	} else if l.peek() == 'l' || l.peek() == 'L' {
		l.advance()
		if l.peek() == 'l' || l.peek() == 'L' {
			l.advance()
		}
	} else if l.peek() == 'u' || l.peek() == 'U' {
		l.advance()
	}

	return l.input[start:l.pos]
}

func (l *Lexer) readIdentifier() string {
	start := l.pos
	for unicode.IsLetter(rune(l.peek())) || unicode.IsDigit(rune(l.peek())) || l.peek() == '_' {
		l.advance()
	}
	return l.input[start:l.pos]
}

func (l *Lexer) identifierType(word string) TokenType {
	keywords := map[string]TokenType{
		"if": TokenIf, "else": TokenElse, "for": TokenFor, "while": TokenWhile,
		"do": TokenDo, "switch": TokenSwitch, "case": TokenCase, "default": TokenDefault,
		"break": TokenBreak, "continue": TokenContinue, "return": TokenReturn, "goto": TokenGoto,
		"struct": TokenStruct, "union": TokenUnion, "enum": TokenEnum, "typedef": TokenTypedef,
		"const": TokenConst, "volatile": TokenVolatile, "static": TokenStatic, "extern": TokenExtern,
		"inline": TokenInline, "register": TokenRegister, "auto": TokenAuto,
		"signed": TokenSigned, "unsigned": TokenUnsigned, "void": TokenVoid,
		"bool": TokenBool, "char": TokenChar, "short": TokenShort, "int": TokenInt,
		"long": TokenLong, "float": TokenFloat, "double": TokenDouble,
		"string": TokenString, "very": TokenVery,
		"true": TokenTrue, "false": TokenFalse, "null": TokenNull,
		"sizeof": TokenSizeof, "typeof": TokenTypeof,
		"printel": TokenPrintel, "scanel": TokenScanel, "timer": TokenTimer,
	}

	if tok, ok := keywords[word]; ok {
		return tok
	}
	return TokenIdentifier
}

func (l *Lexer) makeToken(tokType TokenType, lexeme string) Token {
	return Token{
		Type:   tokType,
		Lexeme: lexeme,
		Line:   l.line,
		Column: l.column - len(lexeme),
		File:   l.file,
	}
}

func (l *Lexer) nextToken() Token {
	l.skipWhitespace()

	// Skip comments
	for l.peek() == '/' && (l.peekNext() == '/' || l.peekNext() == '*') {
		l.skipComment()
		l.skipWhitespace()
	}

	startLine := l.line
	startCol := l.column

	ch := l.peek()

	if ch == 0 {
		return l.makeToken(TokenEOF, "")
	}

	if ch == '\\n' {
		l.advance()
		return l.makeToken(TokenNewline, "\\n")
	}

	// String literals
	if ch == '"' {
		str := l.readString('"')
		tok := l.makeToken(TokenStringLiteral, str)
		tok.StrVal = strings.Trim(str, `"`)
		return tok
	}

	// Character literals
	if ch == '\'' {
		str := l.readString('\'')
		tok := l.makeToken(TokenCharLiteral, str)
		if len(str) > 2 {
			if str[1] == '\\\\' {
				switch str[2] {
				case 'n':
					tok.CharVal = '\\n'
				case 't':
					tok.CharVal = '\\t'
				case 'r':
					tok.CharVal = '\\r'
				case '0':
					tok.CharVal = 0
				default:
					tok.CharVal = rune(str[2])
				}
			} else {
				tok.CharVal = rune(str[1])
			}
		}
		return tok
	}

	// Numbers
	if unicode.IsDigit(rune(ch)) {
		num := l.readNumber()
		if strings.Contains(num, ".") || strings.Contains(num, "e") || strings.Contains(num, "E") {
			tok := l.makeToken(TokenFloatLiteral, num)
			// Parse float value
			return tok
		}
		tok := l.makeToken(TokenIntLiteral, num)
		// Parse int value
		return tok
	}

	// Identifiers and keywords
	if unicode.IsLetter(rune(ch)) || ch == '_' {
		id := l.readIdentifier()
		tokType := l.identifierType(id)
		tok := l.makeToken(tokType, id)
		if tokType == TokenTrue {
			tok.BoolVal = true
		} else if tokType == TokenFalse {
			tok.BoolVal = false
		}
		return tok
	}

	// Preprocessor directives
	if ch == '#' {
		l.advance()
		l.skipWhitespace()
		directive := l.readIdentifier()
		tokType := TokenError
		switch directive {
		case "include":
			tokType = TokenHashInclude
		case "define":
			tokType = TokenHashDefine
		case "ifdef":
			tokType = TokenHashIfdef
		case "ifndef":
			tokType = TokenHashIfndef
		case "if":
			tokType = TokenHashIf
		case "elif":
			tokType = TokenHashElif
		case "else":
			tokType = TokenHashElse
		case "endif":
			tokType = TokenHashEndif
		case "undef":
			tokType = TokenHashUndef
		case "error":
			tokType = TokenHashError
		case "pragma":
			tokType = TokenHashPragma
		case "line":
			tokType = TokenHashLine
		}
		return l.makeToken(tokType, "#")
	}

	// Two-character operators
	twoCharOps := map[string]TokenType{
		"++": TokenInc, "--": TokenDec,
		"==": TokenEq, "!=": TokenNe, "<=": TokenLe, ">=": TokenGe,
		"&&": TokenLogicalAnd, "||": TokenLogicalOr,
		"<<": TokenLShift, ">>": TokenRShift,
		"+=": TokenPlusAssign, "-=": TokenMinusAssign,
		"*=": TokenStarAssign, "/=": TokenSlashAssign,
		"%=": TokenPercentAssign,
		"&=": TokenAndAssign, "|=": TokenOrAssign,
		"^=": TokenXorAssign,
		"<<=": TokenLShiftAssign, ">>=": TokenRShiftAssign,
	}

	if l.pos+1 < len(l.input) {
		twoChar := l.input[l.pos : l.pos+2]
		if tokType, ok := twoCharOps[twoChar]; ok {
			l.advance()
			l.advance()
			return l.makeToken(tokType, twoChar)
		}
		if l.pos+2 < len(l.input) {
			threeChar := l.input[l.pos : l.pos+3]
			if tokType, ok := twoCharOps[threeChar]; ok {
				l.advance()
				l.advance()
				l.advance()
				return l.makeToken(tokType, threeChar)
			}
		}
	}

	// Single-character operators
	l.advance()
	ops := map[byte]TokenType{
		'+': TokenPlus, '-': TokenMinus, '*': TokenStar, '/': TokenSlash,
		'%': TokenPercent, '=': TokenAssign, '<': TokenLt, '>': TokenGt,
		'!': TokenLogicalNot, '&': TokenBitAnd, '|': TokenBitOr,
		'^': TokenBitXor, '~': TokenBitNot,
		'(': TokenLParen, ')': TokenRParen,
		'{': TokenLBrace, '}': TokenRBrace,
		'[': TokenLBracket, ']': TokenRBracket,
		';': TokenSemicolon, ':': TokenColon,
		',': TokenComma, '.': TokenDot,
		'?': TokenQuestion,
	}

	if tokType, ok := ops[ch]; ok {
		return l.makeToken(tokType, string(ch))
	}

	// Arrow operator ->
	if ch == '-' && l.peek() == '>' {
		l.advance()
		l.advance()
		return l.makeToken(TokenArrow, "->")
	}

	return l.makeToken(TokenError, string(ch))
}

func (l *Lexer) Tokenize() ([]Token, error) {
	for {
		tok := l.nextToken()
		l.tokens = append(l.tokens, tok)
		if tok.Type == TokenEOF {
			break
		}
	}
	return l.tokens, nil
}

func (l *Lexer) Errors() []error {
	return l.errors
}