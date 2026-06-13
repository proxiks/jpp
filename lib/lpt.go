package protocol

import "encoding/json"

// Message is the base LSP message type
type Message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      interface{}     `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *ResponseError  `json:"error,omitempty"`
}

// ResponseError represents an LSP error
type ResponseError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Position in a document
type Position struct {
	Line      uint32 `json:"line"`
	Character uint32 `json:"character"`
}

// Range in a document
type Range struct {
	Start Position `json:"start"`
	End   Position `json:"end"`
}

// Location in a document
type Location struct {
	URI   string `json:"uri"`
	Range Range  `json:"range"`
}

// TextDocumentIdentifier identifies a document
type TextDocumentIdentifier struct {
	URI string `json:"uri"`
}

// VersionedTextDocumentIdentifier adds version info
type VersionedTextDocumentIdentifier struct {
	TextDocumentIdentifier
	Version int32 `json:"version"`
}

// TextDocumentItem represents a document at open time
type TextDocumentItem struct {
	URI        string `json:"uri"`
	LanguageID string `json:"languageId"`
	Version    int32  `json:"version"`
	Text       string `json:"text"`
}

// TextDocumentContentChangeEvent represents a change
type TextDocumentContentChangeEvent struct {
	Range       *Range `json:"range,omitempty"`
	RangeLength uint32 `json:"rangeLength,omitempty"`
	Text        string `json:"text"`
}

// TextDocumentPositionParams is used for position-based requests
type TextDocumentPositionParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
	Position     Position               `json:"position"`
}

// DidOpenTextDocumentParams
type DidOpenTextDocumentParams struct {
	TextDocument TextDocumentItem `json:"textDocument"`
}

// DidChangeTextDocumentParams
type DidChangeTextDocumentParams struct {
	TextDocument   VersionedTextDocumentIdentifier  `json:"textDocument"`
	ContentChanges []TextDocumentContentChangeEvent `json:"contentChanges"`
}

// DidCloseTextDocumentParams
type DidCloseTextDocumentParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
}

// DidSaveTextDocumentParams
type DidSaveTextDocumentParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
	Text         *string                `json:"text,omitempty"`
}

// CompletionParams
type CompletionParams struct {
	TextDocumentPositionParams
	Context *CompletionContext `json:"context,omitempty"`
}

// CompletionContext
type CompletionContext struct {
	TriggerKind      CompletionTriggerKind `json:"triggerKind"`
	TriggerCharacter *string               `json:"triggerCharacter,omitempty"`
}

// CompletionTriggerKind
type CompletionTriggerKind int

const (
	Invoked                         CompletionTriggerKind = 1
	TriggerCharacterKind            CompletionTriggerKind = 2
	TriggerForIncompleteCompletions CompletionTriggerKind = 3
)

// CompletionItem
type CompletionItem struct {
	Label            string             `json:"label"`
	Kind             CompletionItemKind `json:"kind,omitempty"`
	Detail           string             `json:"detail,omitempty"`
	Documentation    string             `json:"documentation,omitempty"`
	InsertText       string             `json:"insertText,omitempty"`
	InsertTextFormat InsertTextFormat   `json:"insertTextFormat,omitempty"`
	SortText         string             `json:"sortText,omitempty"`
	FilterText       string             `json:"filterText,omitempty"`
}

// CompletionItemKind
type CompletionItemKind int

const (
	TextCompletion          CompletionItemKind = 1
	MethodCompletion        CompletionItemKind = 2
	FunctionCompletion      CompletionItemKind = 3
	ConstructorCompletion   CompletionItemKind = 4
	FieldCompletion         CompletionItemKind = 5
	VariableCompletion      CompletionItemKind = 6
	ClassCompletion         CompletionItemKind = 7
	InterfaceCompletion     CompletionItemKind = 8
	ModuleCompletion        CompletionItemKind = 9
	PropertyCompletion      CompletionItemKind = 10
	UnitCompletion          CompletionItemKind = 11
	ValueCompletion         CompletionItemKind = 12
	EnumCompletion          CompletionItemKind = 13
	KeywordCompletion       CompletionItemKind = 14
	SnippetCompletion       CompletionItemKind = 15
	ColorCompletion         CompletionItemKind = 16
	FileCompletion          CompletionItemKind = 17
	ReferenceCompletion     CompletionItemKind = 18
	FolderCompletion        CompletionItemKind = 19
	EnumMemberCompletion    CompletionItemKind = 20
	ConstantCompletion      CompletionItemKind = 21
	StructCompletion        CompletionItemKind = 22
	EventCompletion         CompletionItemKind = 23
	OperatorCompletion      CompletionItemKind = 24
	TypeParameterCompletion CompletionItemKind = 25
)

// InsertTextFormat
type InsertTextFormat int

const (
	PlainTextFormat InsertTextFormat = 1
	SnippetFormat   InsertTextFormat = 2
)

// HoverParams
type HoverParams struct {
	TextDocumentPositionParams
}

// Hover
type Hover struct {
	Contents MarkupContent `json:"contents"`
	Range    *Range        `json:"range,omitempty"`
}

// MarkupContent
type MarkupContent struct {
	Kind  string `json:"kind"`
	Value string `json:"value"`
}

// DefinitionParams
type DefinitionParams struct {
	TextDocumentPositionParams
}

// DocumentSymbolParams
type DocumentSymbolParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
}

// DocumentSymbol
type DocumentSymbol struct {
	Name           string           `json:"name"`
	Detail         string           `json:"detail,omitempty"`
	Kind           SymbolKind       `json:"kind"`
	Range          Range            `json:"range"`
	SelectionRange Range            `json:"selectionRange"`
	Children       []DocumentSymbol `json:"children,omitempty"`
}

// SymbolKind
type SymbolKind int

const (
	FileSymbol          SymbolKind = 1
	ModuleSymbol        SymbolKind = 2
	NamespaceSymbol     SymbolKind = 3
	PackageSymbol       SymbolKind = 4
	ClassSymbol         SymbolKind = 5
	MethodSymbol        SymbolKind = 6
	PropertySymbol      SymbolKind = 7
	FieldSymbol         SymbolKind = 8
	ConstructorSymbol   SymbolKind = 9
	EnumSymbol          SymbolKind = 10
	InterfaceSymbol     SymbolKind = 11
	FunctionSymbol      SymbolKind = 12
	VariableSymbol      SymbolKind = 13
	ConstantSymbol      SymbolKind = 14
	StringSymbol        SymbolKind = 15
	NumberSymbol        SymbolKind = 16
	BooleanSymbol       SymbolKind = 17
	ArraySymbol         SymbolKind = 18
	ObjectSymbol        SymbolKind = 19
	KeySymbol           SymbolKind = 20
	NullSymbol          SymbolKind = 21
	EnumMemberSymbol    SymbolKind = 22
	StructSymbol        SymbolKind = 23
	EventSymbol         SymbolKind = 24
	OperatorSymbol      SymbolKind = 25
	TypeParameterSymbol SymbolKind = 26
)

// Diagnostic
type Diagnostic struct {
	Range    Range             `json:"range"`
	Severity DiagnosticSeverity `json:"severity,omitempty"`
	Code     string            `json:"code,omitempty"`
	Source   string            `json:"source,omitempty"`
	Message  string            `json:"message"`
}

// DiagnosticSeverity
type DiagnosticSeverity int

const (
	ErrorSeverity       DiagnosticSeverity = 1
	WarningSeverity     DiagnosticSeverity = 2
	InformationSeverity DiagnosticSeverity = 3
	HintSeverity        DiagnosticSeverity = 4
)

// PublishDiagnosticsParams
type PublishDiagnosticsParams struct {
	URI         string       `json:"uri"`
	Version     int32        `json:"version,omitempty"`
	Diagnostics []Diagnostic `json:"diagnostics"`
}

// DocumentDiagnosticParams
type DocumentDiagnosticParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
	Identifier   string                 `json:"identifier,omitempty"`
	PreviousResultID *string            `json:"previousResultId,omitempty"`
}

// DocumentDiagnosticReport
type DocumentDiagnosticReport struct {
	Kind        string       `json:"kind"`
	ResultID    string       `json:"resultId,omitempty"`
	Items       []Diagnostic `json:"items,omitempty"`
	Version     int32        `json:"version,omitempty"`
}

// DocumentDiagnosticReportKind
type DocumentDiagnosticReportKind string

const (
	DocumentDiagnosticReportKindFull    DocumentDiagnosticReportKind = "full"
	DocumentDiagnosticReportKindUnchanged DocumentDiagnosticReportKind = "unchanged"
)

// DocumentFormattingParams
type DocumentFormattingParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
	Options      FormattingOptions      `json:"options"`
}

// FormattingOptions
type FormattingOptions struct {
	TabSize      uint32 `json:"tabSize"`
	InsertSpaces bool   `json:"insertSpaces"`
}

// TextEdit
type TextEdit struct {
	Range   Range  `json:"range"`
	NewText string `json:"newText"`
}

// RenameParams
type RenameParams struct {
	TextDocumentPositionParams
	NewName string `json:"newName"`
}

// WorkspaceEdit
type WorkspaceEdit struct {
	Changes         map[string][]TextEdit `json:"changes,omitempty"`
	DocumentChanges []TextDocumentEdit    `json:"documentChanges,omitempty"`
}

// TextDocumentEdit
type TextDocumentEdit struct {
	TextDocument VersionedTextDocumentIdentifier `json:"textDocument"`
	Edits        []TextEdit                      `json:"edits"`
}

// SignatureHelpParams
type SignatureHelpParams struct {
	TextDocumentPositionParams
	Context *SignatureHelpContext `json:"context,omitempty"`
}

// SignatureHelpContext
type SignatureHelpContext struct {
	TriggerKind         SignatureHelpTriggerKind `json:"triggerKind"`
	TriggerCharacter    *string                  `json:"triggerCharacter,omitempty"`
	IsRetrigger         bool                     `json:"isRetrigger"`
	ActiveSignatureHelp *SignatureHelp           `json:"activeSignatureHelp,omitempty"`
}

// SignatureHelpTriggerKind
type SignatureHelpTriggerKind int

const (
	InvokedTrigger          SignatureHelpTriggerKind = 1
	TriggerCharacterTrigger SignatureHelpTriggerKind = 2
	ContentChangeTrigger    SignatureHelpTriggerKind = 3
)

// SignatureHelp
type SignatureHelp struct {
	Signatures      []SignatureInformation `json:"signatures"`
	ActiveSignature uint32                 `json:"activeSignature,omitempty"`
	ActiveParameter uint32                 `json:"activeParameter,omitempty"`
}

// SignatureInformation
type SignatureInformation struct {
	Label           string                 `json:"label"`
	Documentation   string                 `json:"documentation,omitempty"`
	Parameters      []ParameterInformation `json:"parameters,omitempty"`
}

// ParameterInformation
type ParameterInformation struct {
	Label         string `json:"label"`
	Documentation string `json:"documentation,omitempty"`
}

// CodeActionParams
type CodeActionParams struct {
	TextDocument TextDocumentIdentifier `json:"textDocument"`
	Range        Range                  `json:"range"`
	Context      CodeActionContext      `json:"context"`
}

// CodeActionContext
type CodeActionContext struct {
	Diagnostics []Diagnostic `json:"diagnostics"`
	Only        []string     `json:"only,omitempty"`
}

// CodeAction
type CodeAction struct {
	Title       string        `json:"title"`
	Kind        string        `json:"kind,omitempty"`
	Diagnostics []Diagnostic  `json:"diagnostics,omitempty"`
	Edit        *WorkspaceEdit `json:"edit,omitempty"`
	Command     *Command      `json:"command,omitempty"`
}

// Command
type Command struct {
	Title     string        `json:"title"`
	Command   string        `json:"command"`
	Arguments []interface{} `json:"arguments,omitempty"`
}

// WorkspaceSymbolParams
type WorkspaceSymbolParams struct {
	Query string `json:"query"`
}

// WorkspaceSymbol
type WorkspaceSymbol struct {
	Name          string     `json:"name"`
	Kind          SymbolKind `json:"kind"`
	Location      Location   `json:"location"`
	ContainerName string     `json:"containerName,omitempty"`
}

// InitializeParams
type InitializeParams struct {
	ProcessID             int                `json:"processId"`
	ClientInfo            *ClientInfo        `json:"clientInfo,omitempty"`
	Locale                string             `json:"locale,omitempty"`
	RootPath              *string            `json:"rootPath,omitempty"`
	RootURI               string             `json:"rootUri,omitempty"`
	InitializationOptions interface{}        `json:"initializationOptions,omitempty"`
	Capabilities          ClientCapabilities `json:"capabilities"`
	Trace                 string             `json:"trace,omitempty"`
	WorkspaceFolders      []WorkspaceFolder  `json:"workspaceFolders,omitempty"`
}

// ClientInfo
type ClientInfo struct {
	Name    string `json:"name"`
	Version string `json:"version,omitempty"`
}

// ClientCapabilities
type ClientCapabilities struct {
	Workspace    WorkspaceClientCapabilities    `json:"workspace,omitempty"`
	TextDocument TextDocumentClientCapabilities `json:"textDocument,omitempty"`
}

// WorkspaceClientCapabilities
type WorkspaceClientCapabilities struct {
	ApplyEdit              bool `json:"applyEdit,omitempty"`
	WorkspaceEdit          struct {
		DocumentChanges bool `json:"documentChanges,omitempty"`
	} `json:"workspaceEdit,omitempty"`
	DidChangeConfiguration struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
	} `json:"didChangeConfiguration,omitempty"`
	DidChangeWatchedFiles struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
	} `json:"didChangeWatchedFiles,omitempty"`
	WorkspaceFolders bool `json:"workspaceFolders,omitempty"`
	Configuration    bool `json:"configuration,omitempty"`
}

// TextDocumentClientCapabilities
type TextDocumentClientCapabilities struct {
	Synchronization struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		WillSave            bool `json:"willSave,omitempty"`
		WillSaveWaitUntil   bool `json:"willSaveWaitUntil,omitempty"`
		DidSave             bool `json:"didSave,omitempty"`
	} `json:"synchronization,omitempty"`
	Completion struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		CompletionItem      struct {
			SnippetSupport bool `json:"snippetSupport,omitempty"`
		} `json:"completionItem,omitempty"`
	} `json:"completion,omitempty"`
	Hover struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		ContentFormat       []string `json:"contentFormat,omitempty"`
	} `json:"hover,omitempty"`
	SignatureHelp struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
	} `json:"signatureHelp,omitempty"`
	Definition struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		LinkSupport         bool `json:"linkSupport,omitempty"`
	} `json:"definition,omitempty"`
	DocumentSymbol struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		SymbolKind          struct {
			ValueSet []SymbolKind `json:"valueSet,omitempty"`
		} `json:"symbolKind,omitempty"`
		HierarchicalDocumentSymbolSupport bool `json:"hierarchicalDocumentSymbolSupport,omitempty"`
	} `json:"documentSymbol,omitempty"`
	Formatting struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
	} `json:"formatting,omitempty"`
	Rename struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		PrepareSupport      bool `json:"prepareSupport,omitempty"`
	} `json:"rename,omitempty"`
	CodeAction struct {
		DynamicRegistration bool `json:"dynamicRegistration,omitempty"`
		CodeActionLiteralSupport struct {
			CodeActionKind struct {
				ValueSet []string `json:"valueSet"`
			} `json:"codeActionKind"`
		} `json:"codeActionLiteralSupport,omitempty"`
	} `json:"codeAction,omitempty"`
}

// WorkspaceFolder
type WorkspaceFolder struct {
	URI  string `json:"uri"`
	Name string `json:"name"`
}

// InitializeResult
type InitializeResult struct {
	Capabilities ServerCapabilities `json:"capabilities"`
	ServerInfo   *ServerInfo        `json:"serverInfo,omitempty"`
}

// ServerCapabilities
type ServerCapabilities struct {
	TextDocumentSync                 *TextDocumentSyncOptions `json:"textDocumentSync,omitempty"`
	CompletionProvider               *CompletionOptions         `json:"completionProvider,omitempty"`
	HoverProvider                    bool                      `json:"hoverProvider,omitempty"`
	SignatureHelpProvider            *SignatureHelpOptions    `json:"signatureHelpProvider,omitempty"`
	DefinitionProvider               bool                      `json:"definitionProvider,omitempty"`
	DocumentSymbolProvider           bool                      `json:"documentSymbolProvider,omitempty"`
	CodeActionProvider               bool                      `json:"codeActionProvider,omitempty"`
	DocumentFormattingProvider       bool                      `json:"documentFormattingProvider,omitempty"`
	RenameProvider                   bool                      `json:"renameProvider,omitempty"`
	WorkspaceSymbolProvider          bool                      `json:"workspaceSymbolProvider,omitempty"`
	DiagnosticProvider               *DiagnosticOptions       `json:"diagnosticProvider,omitempty"`
}

// TextDocumentSyncOptions
type TextDocumentSyncOptions struct {
	OpenClose         bool             `json:"openClose,omitempty"`
	Change            TextDocumentSyncKind `json:"change,omitempty"`
	WillSave          bool             `json:"willSave,omitempty"`
	WillSaveWaitUntil bool             `json:"willSaveWaitUntil,omitempty"`
	Save              *SaveOptions     `json:"save,omitempty"`
}

// TextDocumentSyncKind
type TextDocumentSyncKind int

const (
	NoneSync        TextDocumentSyncKind = 0
	FullSync        TextDocumentSyncKind = 1
	IncrementalSync TextDocumentSyncKind = 2
)

// SaveOptions
type SaveOptions struct {
	IncludeText bool `json:"includeText,omitempty"`
}

// CompletionOptions
type CompletionOptions struct {
	ResolveProvider   bool     `json:"resolveProvider,omitempty"`
	TriggerCharacters []string `json:"triggerCharacters,omitempty"`
}

// SignatureHelpOptions
type SignatureHelpOptions struct {
	TriggerCharacters []string `json:"triggerCharacters,omitempty"`
}

// DiagnosticOptions
type DiagnosticOptions struct {
	Identifier            string `json:"identifier,omitempty"`
	InterFileDependencies bool   `json:"interFileDependencies,omitempty"`
	WorkspaceDiagnostics  bool   `json:"workspaceDiagnostics,omitempty"`
}

// ServerInfo
type ServerInfo struct {
	Name    string `json:"name"`
	Version string `json:"version,omitempty"`
}