// ============================================================
// J++ LEXER - Written in C#
// Unity Game Development Tokenizer
// BSD-2-Clause License
// ============================================================

using System;
using System.Collections.Generic;
using System.Text;

namespace Jpp.Unity
{
    // Token Types
    public enum TokenType
    {
        // Basic
        EOF, NEWLINE, IDENT, NUMBER, STRING,
        
        // Unity Keywords
        GAME, MONOBEHAVIOUR, PUBLIC, PRIVATE, PROTECTED,
        STATIC, VIRTUAL, OVERRIDE, ABSTRACT, SEALED,
        
        // J++ Physics/Macro
        INC, MAQ, DEFINE, FORMULA, PLASMA, CALL,
        DATA, FLAGACTION, REACT, ACTION, MEASURE,
        
        // Types
        VEC2, VEC3, VEC4, MAT2, MAT3, MAT4, QUAT,
        F32, F64, I32, I64, USIZE, BOOL, VOID,
        
        // Unity Types
        GAMEOBJECT, TRANSFORM, RIGIDBODY, COLLIDER,
        ANIMATOR, CAMERA, LIGHT, PARTICRE, AUDIO,
        TEXTURE, MATERIAL, SHADER, SCRIPT,
        
        // Operators
        STAR, CARET, BANG, DOLLAR, AT, TILDE,
        PERCENT, EQUAL, COLON, SEMICOLON, COMMA,
        DOT, DOTSTAR, DOTSLASH, DOTCARET, BACKSLASH,
        PLUS, MINUS, SLASH, MOD,
        
        // Assignment
        ASSIGN, PLUS_ASSIGN, MINUS_ASSIGN, STAR_ASSIGN, SLASH_ASSIGN,
        
        // Comparison
        EQ, NE, LT, GT, LE, GE, AND, OR, NOT,
        
        // Brackets
        LPAREN, RPAREN, LBRACKET, RBRACKET, LBRACE, RBRACE,
        
        // Unity Lifecycle
        AWAKE, START, UPDATE, FIXEDUPDATE, LATEUPDATE,
        ONENABLE, ONDISABLE, ONDESTROY,
        
        // Unity Events
        ONCOLLISIONENTER, ONCOLLISIONEXIT, ONCOLLISIONSTAY,
        ONTRIGGERENTER, ONTRIGGEREXIT, ONTRIGGERSTAY,
        ONMOUSEDOWN, ONMOUSEUP, ONMOUSEDRAG,
        
        // Unity Input
        INPUT, KEYCODE, GETAXIS, GETBUTTON, GETKEY,
        GETMOUSEBUTTON, MOUSEPOSITION,
        
        // Unity Physics
        PHYSICS, RAYCAST, RIGIDBODY_TYPE, COLLISION, FORCEMODE,
        
        // Unity UI
        UI, CANVAS, BUTTON, SLIDER, TEXT, IMAGE, PANEL,
        
        // Unity Networking
        NETWORK, SYNCVAR, COMMAND, CLIENTRPC, TARGETRPC,
        NETWORKBEHAVIOUR, NETWORKIDENTITY, NETWORKSERVER,
        
        // Unity Audio
        AUDIO, AUDIOSOURCE, AUDIOCLIP, PLAY, STOP, PAUSE,
        
        // Unity Animation
        ANIMATOR, ANIMATION, TRIGGER, BOOL_PARAM, FLOAT_PARAM, INT_PARAM,
        
        // Coroutine
        COROUTINE, YIELD, WAITFORSECONDS, WAITFORFIXEDUPDATE,
        WAITFORENDOFFRAME, STARTCOROUTINE, STOPCOROUTINE,
        
        // Shader
        SHADER_KEYWORD, PROPERTIES, SUBSHADER, PASS,
        CGPROGRAM, ENDCG, VERTEX, FRAGMENT,
        
        // XML Networking
        XML, WEBSOCKET, MESSAGE, BROADCAST, RPC_CALL,
        
        // Control Flow
        FN, LET, IF, ELSE, FOR, WHILE, RETURN, LOOP, BREAK,
        CONTINUE, MATCH, WHEN, EXTERN, ASM,
        
        // WebAssembly
        WASM, IMPORT, EXPORT, MEMORY, TABLE, GLOBAL,
    }

    public struct Token
    {
        public TokenType Type;
        public string Literal;
        public int Line;
        public int Column;
    }

    public class Lexer
    {
        private string input;
        private int pos;
        private int readPos;
        private char ch;
        private int line;
        private int col;

        public Lexer(string input)
        {
            this.input = input;
            pos = 0;
            readPos = 0;
            line = 1;
            col = 0;
            ReadChar();
        }

        private void ReadChar()
        {
            if (readPos >= input.Length)
            {
                ch = '\0';
            }
            else
            {
                ch = input[readPos];
            }
            pos = readPos;
            readPos++;
            col++;
            if (ch == '\n')
            {
                line++;
                col = 0;
            }
        }

        private char PeekChar()
        {
            if (readPos >= input.Length) return '\0';
            return input[readPos];
        }

        private void SkipWhitespace()
        {
            while (ch == ' ' || ch == '\t' || ch == '\r')
            {
                ReadChar();
            }
        }

        private void SkipComment()
        {
            if (ch == '/' && PeekChar() == '/')
            {
                while (ch != '\n' && ch != '\0')
                {
                    ReadChar();
                }
            }
            else if (ch == '/' && PeekChar() == '*')
            {
                ReadChar(); ReadChar();
                while (!(ch == '*' && PeekChar() == '/') && ch != '\0')
                {
                    ReadChar();
                }
                if (ch != '\0') { ReadChar(); ReadChar(); }
            }
        }

        private string ReadIdentifier()
        {
            int start = pos;
            while (IsLetter(ch) || IsDigit(ch) || ch == '_')
            {
                ReadChar();
            }
            return input.Substring(start, pos - start);
        }

        private string ReadNumber()
        {
            int start = pos;
            bool hasDot = false;
            bool hasExp = false;

            while (IsDigit(ch) || ch == '.' || ch == 'e' || ch == 'E' || 
                   ch == '-' || ch == '+')
            {
                if (ch == '.')
                {
                    if (hasDot) break;
                    hasDot = true;
                }
                if (ch == 'e' || ch == 'E')
                {
                    if (hasExp) break;
                    hasExp = true;
                }
                ReadChar();
            }
            return input.Substring(start, pos - start);
        }

        private string ReadString()
        {
            char quote = ch;
            ReadChar();
            int start = pos;
            while (ch != quote && ch != '\0')
            {
                ReadChar();
            }
            string str = input.Substring(start, pos - start);
            if (ch == quote) ReadChar();
            return str;
        }

        private string ReadPercentBlock()
        {
            ReadChar(); // consume %
            int start = pos;
            while (IsLetter(ch) || ch == '_')
            {
                ReadChar();
            }
            return input.Substring(start, pos - start);
        }

        private static bool IsLetter(char ch)
        {
            return char.IsLetter(ch) || ch == '_';
        }

        private static bool IsDigit(char ch)
        {
            return char.IsDigit(ch);
        }

        private static readonly Dictionary<string, TokenType> Keywords = new()
        {
            // Unity
            ["game"] = TokenType.GAME,
            ["monobehaviour"] = TokenType.MONOBEHAVIOUR,
            ["public"] = TokenType.PUBLIC,
            ["private"] = TokenType.PRIVATE,
            ["protected"] = TokenType.PROTECTED,
            ["static"] = TokenType.STATIC,
            ["virtual"] = TokenType.VIRTUAL,
            ["override"] = TokenType.OVERRIDE,
            ["abstract"] = TokenType.ABSTRACT,
            ["sealed"] = TokenType.SEALED,
            
            // J++ Physics
            ["formula"] = TokenType.FORMULA,
            ["plasma"] = TokenType.PLASMA,
            ["react"] = TokenType.REACT,
            ["action"] = TokenType.ACTION,
            ["measure"] = TokenType.MEASURE,
            
            // Types
            ["vec2"] = TokenType.VEC2,
            ["vec3"] = TokenType.VEC3,
            ["vec4"] = TokenType.VEC4,
            ["mat2"] = TokenType.MAT2,
            ["mat3"] = TokenType.MAT3,
            ["mat4"] = TokenType.MAT4,
            ["quat"] = TokenType.QUAT,
            ["f32"] = TokenType.F32,
            ["f64"] = TokenType.F64,
            ["i32"] = TokenType.I32,
            ["i64"] = TokenType.I64,
            ["usize"] = TokenType.USIZE,
            ["bool"] = TokenType.BOOL,
            ["void"] = TokenType.VOID,
            
            // Unity Types
            ["GameObject"] = TokenType.GAMEOBJECT,
            ["Transform"] = TokenType.TRANSFORM,
            ["Rigidbody"] = TokenType.RIGIDBODY,
            ["Collider"] = TokenType.COLLIDER,
            ["Animator"] = TokenType.ANIMATOR,
            ["Camera"] = TokenType.CAMERA,
            ["Light"] = TokenType.LIGHT,
            ["ParticleSystem"] = TokenType.PARTICRE,
            ["AudioSource"] = TokenType.AUDIO,
            ["Texture"] = TokenType.TEXTURE,
            ["Material"] = TokenType.MATERIAL,
            ["Shader"] = TokenType.SHADER,
            
            // Lifecycle
            ["Awake"] = TokenType.AWAKE,
            ["Start"] = TokenType.START,
            ["Update"] = TokenType.UPDATE,
            ["FixedUpdate"] = TokenType.FIXEDUPDATE,
            ["LateUpdate"] = TokenType.LATEUPDATE,
            ["OnEnable"] = TokenType.ONENABLE,
            ["OnDisable"] = TokenType.ONDISABLE,
            ["OnDestroy"] = TokenType.ONDESTROY,
            
            // Events
            ["OnCollisionEnter"] = TokenType.ONCOLLISIONENTER,
            ["OnCollisionExit"] = TokenType.ONCOLLISIONEXIT,
            ["OnCollisionStay"] = TokenType.ONCOLLISIONSTAY,
            ["OnTriggerEnter"] = TokenType.ONTRIGGERENTER,
            ["OnTriggerExit"] = TokenType.ONTRIGGEREXIT,
            ["OnTriggerStay"] = TokenType.ONTRIGGERSTAY,
            ["OnMouseDown"] = TokenType.ONMOUSEDOWN,
            ["OnMouseUp"] = TokenType.ONMOUSEUP,
            ["OnMouseDrag"] = TokenType.ONMOUSEDRAG,
            
            // Input
            ["Input"] = TokenType.INPUT,
            ["KeyCode"] = TokenType.KEYCODE,
            ["GetAxis"] = TokenType.GETAXIS,
            ["GetButton"] = TokenType.GETBUTTON,
            ["GetKey"] = TokenType.GETKEY,
            ["GetMouseButton"] = TokenType.GETMOUSEBUTTON,
            ["mousePosition"] = TokenType.MOUSEPOSITION,
            
            // Physics
            ["Physics"] = TokenType.PHYSICS,
            ["Raycast"] = TokenType.RAYCAST,
            ["ForceMode"] = TokenType.FORCEMODE,
            
            // UI
            ["UI"] = TokenType.UI,
            ["Canvas"] = TokenType.CANVAS,
            ["Button"] = TokenType.BUTTON,
            ["Slider"] = TokenType.SLIDER,
            ["Text"] = TokenType.TEXT,
            ["Image"] = TokenType.IMAGE,
            ["Panel"] = TokenType.PANEL,
            
            // Networking
            ["Network"] = TokenType.NETWORK,
            ["SyncVar"] = TokenType.SYNCVAR,
            ["Command"] = TokenType.COMMAND,
            ["ClientRpc"] = TokenType.CLIENTRPC,
            ["TargetRpc"] = TokenType.TARGETRPC,
            ["NetworkBehaviour"] = TokenType.NETWORKBEHAVIOUR,
            ["NetworkIdentity"] = TokenType.NETWORKIDENTITY,
            ["NetworkServer"] = TokenType.NETWORKSERVER,
            
            // Audio
            ["Audio"] = TokenType.AUDIO,
            ["AudioSource"] = TokenType.AUDIOSOURCE,
            ["AudioClip"] = TokenType.AUDIOCLIP,
            ["Play"] = TokenType.PLAY,
            ["Stop"] = TokenType.STOP,
            ["Pause"] = TokenType.PAUSE,
            
            // Animation
            ["Animator"] = TokenType.ANIMATOR,
            ["Animation"] = TokenType.ANIMATION,
            ["SetTrigger"] = TokenType.TRIGGER,
            ["SetBool"] = TokenType.BOOL_PARAM,
            ["SetFloat"] = TokenType.FLOAT_PARAM,
            ["SetInt"] = TokenType.INT_PARAM,
            
            // Coroutine
            ["coroutine"] = TokenType.COROUTINE,
            ["yield"] = TokenType.YIELD,
            ["WaitForSeconds"] = TokenType.WAITFORSECONDS,
            ["WaitForFixedUpdate"] = TokenType.WAITFORFIXEDUPDATE,
            ["WaitForEndOfFrame"] = TokenType.WAITFORENDOFFRAME,
            ["StartCoroutine"] = TokenType.STARTCOROUTINE,
            ["StopCoroutine"] = TokenType.STOPCOROUTINE,
            
            // Shader
            ["shader"] = TokenType.SHADER_KEYWORD,
            ["Properties"] = TokenType.PROPERTIES,
            ["SubShader"] = TokenType.SUBSHADER,
            ["Pass"] = TokenType.PASS,
            ["CGPROGRAM"] = TokenType.CGPROGRAM,
            ["ENDCG"] = TokenType.ENDCG,
            ["vertex"] = TokenType.VERTEX,
            ["fragment"] = TokenType.FRAGMENT,
            
            // XML/Network
            ["xml"] = TokenType.XML,
            ["WebSocket"] = TokenType.WEBSOCKET,
            ["Message"] = TokenType.MESSAGE,
            ["Broadcast"] = TokenType.BROADCAST,
            
            // WASM
            ["wasm"] = TokenType.WASM,
            ["import"] = TokenType.IMPORT,
            ["export"] = TokenType.EXPORT,
            
            // Control
            ["fn"] = TokenType.FN,
            ["let"] = TokenType.LET,
            ["if"] = TokenType.IF,
            ["else"] = TokenType.ELSE,
            ["for"] = TokenType.FOR,
            ["while"] = TokenType.WHILE,
            ["return"] = TokenType.RETURN,
            ["loop"] = TokenType.LOOP,
            ["break"] = TokenType.BREAK,
            ["continue"] = TokenType.CONTINUE,
            ["match"] = TokenType.MATCH,
            ["when"] = TokenType.WHEN,
            ["extern"] = TokenType.EXTERN,
            ["asm"] = TokenType.ASM,
        };

        public Token NextToken()
        {
            Token tok = new();
            tok.Line = line;
            tok.Column = col;

            SkipWhitespace();
            SkipComment();

            switch (ch)
            {
                case '\0':
                    tok.Type = TokenType.EOF;
                    tok.Literal = "EOF";
                    break;

                case '\n':
                    tok.Type = TokenType.NEWLINE;
                    tok.Literal = "\\n";
                    ReadChar();
                    break;

                case '#':
                    ReadChar();
                    string directive = ReadIdentifier();
                    tok.Literal = "#" + directive;
                    tok.Type = directive switch
                    {
                        "inc" => TokenType.INC,
                        "maq" => TokenType.MAQ,
                        "define" => TokenType.DEFINE,
                        _ => TokenType.IDENT
                    };
                    break;

                case '%':
                    tok.Type = TokenType.DATA;
                    tok.Literal = "%" + ReadPercentBlock() + "%";
                    break;

                case '*':
                    if (IsLetter(PeekChar()))
                    {
                        ReadChar();
                        string ident = ReadIdentifier();
                        tok.Literal = "*" + ident;
                        tok.Type = ident == "flagAction" ? TokenType.FLAGACTION : 
                                   ident == "c" ? TokenType.STAR : TokenType.IDENT;
                    }
                    else
                    {
                        tok.Type = TokenType.STAR;
                        tok.Literal = "*";
                        ReadChar();
                    }
                    break;

                case '^':
                    tok.Type = TokenType.CARET;
                    tok.Literal = "^";
                    ReadChar();
                    break;

                case '!':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.NE;
                        tok.Literal = "!=";
                    }
                    else
                    {
                        tok.Type = TokenType.BANG;
                        tok.Literal = "!";
                    }
                    ReadChar();
                    break;

                case '$':
                    tok.Type = TokenType.DOLLAR;
                    tok.Literal = "$";
                    ReadChar();
                    break;

                case '@':
                    tok.Type = TokenType.AT;
                    tok.Literal = "@";
                    ReadChar();
                    break;

                case '~':
                    tok.Type = TokenType.TILDE;
                    tok.Literal = "~";
                    ReadChar();
                    break;

                case '=':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.EQ;
                        tok.Literal = "==";
                    }
                    else if (PeekChar() == '>')
                    {
                        ReadChar();
                        tok.Type = TokenType.ARROW; // =>
                        tok.Literal = "=>";
                    }
                    else
                    {
                        tok.Type = TokenType.ASSIGN;
                        tok.Literal = "=";
                    }
                    ReadChar();
                    break;

                case '+':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.PLUS_ASSIGN;
                        tok.Literal = "+=";
                    }
                    else
                    {
                        tok.Type = TokenType.PLUS;
                        tok.Literal = "+";
                    }
                    ReadChar();
                    break;

                case '-':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.MINUS_ASSIGN;
                        tok.Literal = "-=";
                    }
                    else if (PeekChar() == '>')
                    {
                        ReadChar();
                        tok.Type = TokenType.ARROW;
                        tok.Literal = "->";
                    }
                    else
                    {
                        tok.Type = TokenType.MINUS;
                        tok.Literal = "-";
                    }
                    ReadChar();
                    break;

                case '/':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.SLASH_ASSIGN;
                        tok.Literal = "/=";
                    }
                    else
                    {
                        tok.Type = TokenType.SLASH;
                        tok.Literal = "/";
                    }
                    ReadChar();
                    break;

                case ':':
                    tok.Type = TokenType.COLON;
                    tok.Literal = ":";
                    ReadChar();
                    break;

                case ';':
                    tok.Type = TokenType.SEMICOLON;
                    tok.Literal = ";";
                    ReadChar();
                    break;

                case ',':
                    tok.Type = TokenType.COMMA;
                    tok.Literal = ",";
                    ReadChar();
                    break;

                case '.':
                    char next = PeekChar();
                    if (next == '*')
                    {
                        ReadChar();
                        tok.Type = TokenType.DOTSTAR;
                        tok.Literal = ".*";
                        ReadChar();
                    }
                    else if (next == '/')
                    {
                        ReadChar();
                        tok.Type = TokenType.DOTSLASH;
                        tok.Literal = "./";
                        ReadChar();
                    }
                    else if (next == '^')
                    {
                        ReadChar();
                        tok.Type = TokenType.DOTCARET;
                        tok.Literal = ".^";
                        ReadChar();
                    }
                    else
                    {
                        tok.Type = TokenType.DOT;
                        tok.Literal = ".";
                        ReadChar();
                    }
                    break;

                case '\\':
                    tok.Type = TokenType.BACKSLASH;
                    tok.Literal = "\\";
                    ReadChar();
                    break;

                case '<':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.LE;
                        tok.Literal = "<=";
                    }
                    else
                    {
                        tok.Type = TokenType.LT;
                        tok.Literal = "<";
                    }
                    ReadChar();
                    break;

                case '>':
                    if (PeekChar() == '=')
                    {
                        ReadChar();
                        tok.Type = TokenType.GE;
                        tok.Literal = ">=";
                    }
                    else
                    {
                        tok.Type = TokenType.GT;
                        tok.Literal = ">";
                    }
                    ReadChar();
                    break;

                case '&':
                    if (PeekChar() == '&')
                    {
                        ReadChar();
                        tok.Type = TokenType.AND;
                        tok.Literal = "&&";
                        ReadChar();
                    }
                    break;

                case '|':
                    if (PeekChar() == '|')
                    {
                        ReadChar();
                        tok.Type = TokenType.OR;
                        tok.Literal = "||";
                        ReadChar();
                    }
                    break;

                case '(':
                    tok.Type = TokenType.LPAREN;
                    tok.Literal = "(";
                    ReadChar();
                    break;

                case ')':
                    tok.Type = TokenType.RPAREN;
                    tok.Literal = ")";
                    ReadChar();
                    break;

                case '[':
                    tok.Type = TokenType.LBRACKET;
                    tok.Literal = "[";
                    ReadChar();
                    break;

                case ']':
                    tok.Type = TokenType.RBRACKET;
                    tok.Literal = "]";
                    ReadChar();
                    break;

                case '{':
                    tok.Type = TokenType.LBRACE;
                    tok.Literal = "{";
                    ReadChar();
                    break;

                case '}':
                    tok.Type = TokenType.RBRACE;
                    tok.Literal = "}";
                    ReadChar();
                    break;

                case '"':
                case '\'':
                    tok.Type = TokenType.STRING;
                    tok.Literal = ReadString();
                    break;

                default:
                    if (IsLetter(ch))
                    {
                        string ident = ReadIdentifier();
                        tok.Literal = ident;
                        
                        // Check for call_ prefix
                        if (ident.StartsWith("call_"))
                        {
                            tok.Type = TokenType.CALL;
                        }
                        else if (Keywords.TryGetValue(ident, out TokenType keywordType))
                        {
                            tok.Type = keywordType;
                        }
                        else
                        {
                            tok.Type = TokenType.IDENT;
                        }
                    }
                    else if (IsDigit(ch))
                    {
                        tok.Type = TokenType.NUMBER;
                        tok.Literal = ReadNumber();
                    }
                    else
                    {
                        tok.Type = TokenType.IDENT;
                        tok.Literal = ch.ToString();
                        ReadChar();
                    }
                    break;
            }

            return tok;
        }
    }
}