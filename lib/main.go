import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/linuxab/jpp/lsp/internal/analysis"
	"github.com/linuxab/jpp/lsp/internal/protocol"
)

type Server struct {
	ctx    context.Context
	logger *log.Logger
	state  *analysis.State
}

func NewServer(logger *log.Logger) *Server {
	return &Server{
		ctx:    context.Background(),
		logger: logger,
		state:  analysis.NewState(),
	}
}

func (s *Server) handleMessage(msg *protocol.Message) (*protocol.Message, error) {
	switch msg.Method {
	case "initialize":
		return s.handleInitialize(msg)
	case "initialized":
		return nil, nil
	case "shutdown":
		return s.handleShutdown(msg)
	case "exit":
		os.Exit(0)
		return nil, nil
	case "textDocument/didOpen":
		return s.handleDidOpen(msg)
	case "textDocument/didChange":
		return s.handleDidChange(msg)
	case "textDocument/didClose":
		return s.handleDidClose(msg)
	case "textDocument/didSave":
		return s.handleDidSave(msg)
	case "textDocument/completion":
		return s.handleCompletion(msg)
	case "textDocument/hover":
		return s.handleHover(msg)
	case "textDocument/definition":
		return s.handleDefinition(msg)
	case "textDocument/documentSymbol":
		return s.handleDocumentSymbol(msg)
	case "textDocument/diagnostic":
		return s.handleDiagnostic(msg)
	case "textDocument/formatting":
		return s.handleFormatting(msg)
	case "textDocument/rename":
		return s.handleRename(msg)
	case "textDocument/signatureHelp":
		return s.handleSignatureHelp(msg)
	case "textDocument/codeAction":
		return s.handleCodeAction(msg)
	case "workspace/symbol":
		return s.handleWorkspaceSymbol(msg)
	default:
		s.logger.Printf("Unhandled method: %s", msg.Method)
		return nil, nil
	}
}

func (s *Server) handleInitialize(msg *protocol.Message) (*protocol.Message, error) {
	result := protocol.InitializeResult{
		Capabilities: protocol.ServerCapabilities{
			TextDocumentSync: &protocol.TextDocumentSyncOptions{
				OpenClose: true,
				Change:    protocol.Incremental,
				Save: &protocol.SaveOptions{
					IncludeText: false,
				},
			},
			CompletionProvider: &protocol.CompletionOptions{
				ResolveProvider:   true,
				TriggerCharacters: []string{".", ":", ">", "#", "("},
			},
			HoverProvider:              true,
			DefinitionProvider:         true,
			DocumentSymbolProvider:     true,
			DiagnosticProvider: &protocol.DiagnosticOptions{
				Identifier:            "jpp",
				InterFileDependencies: false,
				WorkspaceDiagnostics:  false,
			},
			DocumentFormattingProvider: true,
			RenameProvider:             true,
			SignatureHelpProvider: &protocol.SignatureHelpOptions{
				TriggerCharacters: []string{"(", ","},
			},
			CodeActionProvider: true,
			WorkspaceSymbolProvider: true,
		},
		ServerInfo: &protocol.ServerInfo{
			Name:    "jpp-lsp",
			Version: "0.1.0",
		},
	}
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(result),
	}, nil
}

func (s *Server) handleShutdown(msg *protocol.Message) (*protocol.Message, error) {
	return &protocol.Message{ID: msg.ID, Result: json.RawMessage("null")}, nil
}

func (s *Server) handleDidOpen(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DidOpenTextDocumentParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	s.state.OpenDocument(params.TextDocument.URI, params.TextDocument.Text, params.TextDocument.Version)
	return nil, nil
}

func (s *Server) handleDidChange(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DidChangeTextDocumentParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	for _, change := range params.ContentChanges {
		if change.Range == nil {
			s.state.UpdateDocument(params.TextDocument.URI, change.Text, params.TextDocument.Version)
		} else {
			s.state.ApplyIncrementalChange(params.TextDocument.URI, change, params.TextDocument.Version)
		}
	}
	return nil, nil
}

func (s *Server) handleDidClose(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DidCloseTextDocumentParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	s.state.CloseDocument(params.TextDocument.URI)
	return nil, nil
}

func (s *Server) handleDidSave(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DidSaveTextDocumentParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	// Trigger full diagnostics on save
	diagnostics := s.state.GetDiagnostics(params.TextDocument.URI)
	if len(diagnostics) > 0 {
		publish := protocol.PublishDiagnosticsParams{
			URI:         params.TextDocument.URI,
			Diagnostics: diagnostics,
		}
		return &protocol.Message{
			Method: "textDocument/publishDiagnostics",
			Params: mustMarshal(publish),
		}, nil
	}
	return nil, nil
}

func (s *Server) handleCompletion(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.CompletionParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	items := s.state.GetCompletions(params.TextDocument.URI, params.Position)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(items),
	}, nil
}

func (s *Server) handleHover(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.HoverParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	hover := s.state.GetHover(params.TextDocument.URI, params.Position)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(hover),
	}, nil
}

func (s *Server) handleDefinition(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DefinitionParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	locations := s.state.GetDefinition(params.TextDocument.URI, params.Position)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(locations),
	}, nil
}

func (s *Server) handleDocumentSymbol(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DocumentSymbolParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	symbols := s.state.GetDocumentSymbols(params.TextDocument.URI)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(symbols),
	}, nil
}

func (s *Server) handleDiagnostic(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DocumentDiagnosticParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	report := protocol.DocumentDiagnosticReport{
		Kind:        protocol.DocumentDiagnosticReportKindFull,
		ResultID:    "jpp-diagnostics",
		Items:       s.state.GetDiagnostics(params.TextDocument.URI),
		Version:     s.state.GetDocumentVersion(params.TextDocument.URI),
	}
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(report),
	}, nil
}

func (s *Server) handleFormatting(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.DocumentFormattingParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	edits := s.state.FormatDocument(params.TextDocument.URI, params.Options)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(edits),
	}, nil
}

func (s *Server) handleRename(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.RenameParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	workspaceEdit := s.state.Rename(params.TextDocument.URI, params.Position, params.NewName)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(workspaceEdit),
	}, nil
}

func (s *Server) handleSignatureHelp(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.SignatureHelpParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	help := s.state.GetSignatureHelp(params.TextDocument.URI, params.Position)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(help),
	}, nil
}

func (s *Server) handleCodeAction(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.CodeActionParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	actions := s.state.GetCodeActions(params.TextDocument.URI, params.Range)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(actions),
	}, nil
}

func (s *Server) handleWorkspaceSymbol(msg *protocol.Message) (*protocol.Message, error) {
	var params protocol.WorkspaceSymbolParams
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		return nil, err
	}
	symbols := s.state.GetWorkspaceSymbols(params.Query)
	return &protocol.Message{
		ID:     msg.ID,
		Result: mustMarshal(symbols),
	}, nil
}

func mustMarshal(v interface{}) json.RawMessage {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return json.RawMessage(b)
}

func main() {
	logger := log.New(os.Stderr, "[jpp-lsp] ", log.LstdFlags|log.Lshortfile)
	server := NewServer(logger)

	reader := bufio.NewReader(os.Stdin)
	writer := bufio.NewWriter(os.Stdout)

	for {
		// Read Content-Length header
		var contentLength int
		for {
			line, err := reader.ReadString('\\n')
			if err != nil {
				if err == io.EOF {
					return
				}
				logger.Fatal(err)
			}
			line = line[:len(line)-2] // Remove \\r\\n
			if line == "" {
				break
			}
			if _, err := fmt.Sscanf(line, "Content-Length: %d", &contentLength); err == nil {
				continue
			}
		}

		// Read message body
		body := make([]byte, contentLength)
		if _, err := io.ReadFull(reader, body); err != nil {
			logger.Fatal(err)
		}

		var msg protocol.Message
		if err := json.Unmarshal(body, &msg); err != nil {
			logger.Printf("Failed to unmarshal message: %v", err)
			continue
		}

		response, err := server.handleMessage(&msg)
		if err != nil {
			logger.Printf("Error handling message: %v", err)
			continue
		}

		if response != nil {
			responseJSON, err := json.Marshal(response)
			if err != nil {
				logger.Printf("Failed to marshal response: %v", err)
				continue
			}
			fmt.Fprintf(writer, "Content-Length: %d\\r\\n\\r\\n", len(responseJSON))
			writer.Write(responseJSON)
			writer.Flush()
		}
	}
}v