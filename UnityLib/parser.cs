// ============================================================
// J++ PARSER - Written in C#
// Unity Game Development Parser
// BSD-2-Clause License
// ============================================================

using System;
using System.Collections.Generic;

namespace Jpp.Unity
{
    // AST Nodes
    public abstract class AstNode { }

    public class ProgramNode : AstNode
    {
        public List<AstNode> Statements = new();
    }

    public class IncludeNode : AstNode
    {
        public string Module;
    }

    public class MaqNode : AstNode
    {
        public string Domain;
    }

    public class GameClassNode : AstNode
    {
        public string Name;
        public string BaseClass;
        public List<FieldNode> Fields = new();
        public List<MethodNode> Methods = new();
    }

    public class FieldNode : AstNode
    {
        public string AccessModifier; // public, private, protected
        public string Name;
        public string Type;
        public AstNode Initializer;
    }

    public class MethodNode : AstNode
    {
        public string Name;
        public string ReturnType;
        public List<ParameterNode> Parameters = new();
        public List<AstNode> Body = new();
        public bool IsCoroutine;
        public List<string> Attributes = new(); // [SyncVar], [Command], etc.
    }

    public class ParameterNode : AstNode
    {
        public string Name;
        public string Type;
    }

    public class LetNode : AstNode
    {
        public string Name;
        public AstNode Value;
    }

    public class FormulaNode : AstNode
    {
        public string Name;
        public string Target;
        public List<AstNode> Body = new();
    }

    public class IfNode : AstNode
    {
        public AstNode Condition;
        public List<AstNode> ThenBody = new();
        public List<AstNode> ElseBody = new();
    }

    public class ForNode : AstNode
    {
        public string Iterator;
        public AstNode Range;
        public List<AstNode> Body = new();
    }

    public class WhileNode : AstNode
    {
        public AstNode Condition;
        public List<AstNode> Body = new();
    }

    public class ReturnNode : AstNode
    {
        public AstNode Value;
    }

    public class CallNode : AstNode
    {
        public AstNode Function;
        public List<AstNode> Arguments = new();
    }

    public class BinaryOpNode : AstNode
    {
        public string Operator;
        public AstNode Left;
        public AstNode Right;
    }

    public class UnaryOpNode : AstNode
    {
        public string Operator;
        public AstNode Operand;
    }

    public class IdentifierNode : AstNode
    {
        public string Name;
    }

    public class NumberNode : AstNode
    {
        public double Value;
    }

    public class StringNode : AstNode
    {
        public string Value;
    }

    public class Vec3Node : AstNode
    {
        public AstNode X, Y, Z;
    }

    public class MatrixNode : AstNode
    {
        public List<List<AstNode>> Rows = new();
    }

    public class RangeNode : AstNode
    {
        public AstNode Start;
        public AstNode Step;
        public AstNode End;
    }

    public class IndexNode : AstNode
    {
        public AstNode Array;
        public AstNode Index;
    }

    public class MemberAccessNode : AstNode
    {
        public AstNode Object;
        public string Member;
    }

    public class CoroutineNode : AstNode
    {
        public string Name;
        public List<AstNode> Body = new();
    }

    public class YieldNode : AstNode
    {
        public string YieldType;
        public AstNode Value;
    }

    public class ShaderNode : AstNode
    {
        public string Name;
        public List<AstNode> Properties = new();
        public List<AstNode> SubShaders = new();
    }

    public class XmlMessageNode : AstNode
    {
        public string MessageType;
        public Dictionary<string, string> Attributes = new();
    }

    public class WasmImportNode : AstNode
    {
        public string Module;
        public string Name;
        public string Signature;
    }

    public class Parser
    {
        private Lexer lexer;
        private Token curToken;
        private Token peekToken;
        private List<string> errors = new();

        public Parser(Lexer lexer)
        {
            this.lexer = lexer;
            NextToken();
            NextToken();
        }

        private void NextToken()
        {
            curToken = peekToken;
            peekToken = lexer.NextToken();
        }

        private bool CurIs(TokenType t) => curToken.Type == t;
        private bool PeekIs(TokenType t) => peekToken.Type == t;

        private bool ExpectPeek(TokenType t)
        {
            if (PeekIs(t))
            {
                NextToken();
                return true;
            }
            PeekError(t);
            return false;
        }

        private void PeekError(TokenType t)
        {
            errors.Add($"Expected {t}, got {peekToken.Type} at line {peekToken.Line}");
        }

        public List<string> GetErrors() => errors;

        public ProgramNode ParseProgram()
        {
            ProgramNode program = new();

            while (!CurIs(TokenType.EOF))
            {
                var stmt = ParseStatement();
                if (stmt != null) program.Statements.Add(stmt);
                NextToken();
            }

            return program;
        }

        private AstNode ParseStatement()
        {
            return curToken.Type switch
            {
                TokenType.INC => ParseInclude(),
                TokenType.MAQ => ParseMaq(),
                TokenType.DEFINE => ParseDefine(),
                TokenType.GAME => ParseGameClass(),
                TokenType.LET => ParseLet(),
                TokenType.FN => ParseMethod(),
                TokenType.FORMULA => ParseFormula(),
                TokenType.IF => ParseIf(),
                TokenType.FOR => ParseFor(),
                TokenType.WHILE => ParseWhile(),
                TokenType.RETURN => ParseReturn(),
                TokenType.COROUTINE => ParseCoroutine(),
                TokenType.SHADER_KEYWORD => ParseShader(),
                TokenType.XML => ParseXmlMessage(),
                TokenType.WASM => ParseWasmImport(),
                TokenType.NEWLINE => null,
                _ => ParseExpressionStatement()
            };
        }

        private AstNode ParseInclude()
        {
            var node = new IncludeNode();
            NextToken(); // consume <
            node.Module = curToken.Literal;
            ExpectPeek(TokenType.GT);
            return node;
        }

        private AstNode ParseMaq()
        {
            var node = new MaqNode();
            NextToken(); // consume <
            node.Domain = curToken.Literal;
            ExpectPeek(TokenType.GT);
            return node;
        }

        private AstNode ParseDefine()
        {
            NextToken();
            return new IdentifierNode { Name = curToken.Literal };
        }

        private AstNode ParseGameClass()
        {
            var node = new GameClassNode();
            
            // Parse name
            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Name = curToken.Literal;

            // Optional base class
            if (PeekIs(TokenType.COLON))
            {
                NextToken();
                if (!ExpectPeek(TokenType.IDENT)) return null;
                node.BaseClass = curToken.Literal;
            }

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            // Parse body
            while (!CurIs(TokenType.RBRACE) && !CurIs(TokenType.EOF))
            {
                if (CurIs(TokenType.PUBLIC) || CurIs(TokenType.PRIVATE) || 
                    CurIs(TokenType.PROTECTED))
                {
                    ParseGameMember(node);
                }
                else if (CurIs(TokenType.FN) || CurIs(TokenType.COROUTINE))
                {
                    node.Methods.Add(ParseMethod() as MethodNode);
                }
                NextToken();
            }

            return node;
        }

        private void ParseGameMember(GameClassNode game)
        {
            string access = curToken.Literal;
            NextToken();

            if (CurIs(TokenType.STATIC))
            {
                // static field
                NextToken();
            }

            // Type
            string type = curToken.Literal;
            NextToken();

            // Name
            string name = curToken.Literal;
            NextToken();

            FieldNode field = new()
            {
                AccessModifier = access,
                Name = name,
                Type = type
            };

            if (CurIs(TokenType.ASSIGN))
            {
                NextToken();
                field.Initializer = ParseExpression();
            }

            game.Fields.Add(field);
        }

        private AstNode ParseMethod()
        {
            bool isCoroutine = CurIs(TokenType.COROUTINE);
            var node = new MethodNode { IsCoroutine = isCoroutine };

            // Check for attributes [SyncVar], [Command], etc.
            while (CurIs(TokenType.LBRACKET))
            {
                NextToken();
                node.Attributes.Add(curToken.Literal);
                ExpectPeek(TokenType.RBRACKET);
                NextToken();
            }

            if (!isCoroutine) NextToken(); // consume fn

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Name = curToken.Literal;

            if (!ExpectPeek(TokenType.LPAREN)) return null;
            node.Parameters = ParseParameters();

            // Return type
            if (PeekIs(TokenType.ARROW))
            {
                NextToken();
                NextToken();
                node.ReturnType = curToken.Literal;
            }

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            node.Body = ParseBlock();

            return node;
        }

        private List<ParameterNode> ParseParameters()
        {
            var params_list = new List<ParameterNode>();

            if (PeekIs(TokenType.RPAREN))
            {
                NextToken();
                return params_list;
            }

            NextToken();
            params_list.Add(new ParameterNode 
            { 
                Name = curToken.Literal,
                Type = "var" // infer later
            });

            while (PeekIs(TokenType.COMMA))
            {
                NextToken();
                NextToken();
                params_list.Add(new ParameterNode 
                { 
                    Name = curToken.Literal,
                    Type = "var"
                });
            }

            ExpectPeek(TokenType.RPAREN);
            return params_list;
        }

        private List<AstNode> ParseBlock()
        {
            var block = new List<AstNode>();

            while (!CurIs(TokenType.RBRACE) && !CurIs(TokenType.EOF))
            {
                var stmt = ParseStatement();
                if (stmt != null) block.Add(stmt);
                NextToken();
            }

            return block;
        }

        private AstNode ParseLet()
        {
            var node = new LetNode();
            NextToken();
            node.Name = curToken.Literal;
            if (!ExpectPeek(TokenType.ASSIGN)) return null;
            NextToken();
            node.Value = ParseExpression();
            return node;
        }

        private AstNode ParseFormula()
        {
            var node = new FormulaNode();
            
            // Optional *name
            if (PeekIs(TokenType.STAR))
            {
                NextToken();
                NextToken();
                node.Name = curToken.Literal;
            }

            if (!ExpectPeek(TokenType.ASSIGN)) return null;
            NextToken();

            // (plasma) target
            if (CurIs(TokenType.LPAREN))
            {
                NextToken();
                node.Target = curToken.Literal;
                ExpectPeek(TokenType.RPAREN);
            }

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            node.Body = ParseBlock();
            return node;
        }

        private AstNode ParseIf()
        {
            var node = new IfNode();
            NextToken();
            node.Condition = ParseExpression();

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();
            node.ThenBody = ParseBlock();

            if (PeekIs(TokenType.ELSE))
            {
                NextToken();
                if (!ExpectPeek(TokenType.LBRACE)) return null;
                NextToken();
                node.ElseBody = ParseBlock();
            }

            return node;
        }

        private AstNode ParseFor()
        {
            var node = new ForNode();
            NextToken();

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Iterator = curToken.Literal;

            if (!ExpectPeek(TokenType.ASSIGN)) return null;
            NextToken();

            node.Range = ParseRange();

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            node.Body = ParseBlock();
            return node;
        }

        private AstNode ParseRange()
        {
            var node = new RangeNode();
            node.Start = ParseExpression();

            if (!ExpectPeek(TokenType.COLON)) return null;
            NextToken();

            node.Step = ParseExpression();

            if (PeekIs(TokenType.COLON))
            {
                NextToken();
                NextToken();
                node.End = ParseExpression();
            }
            else
            {
                node.End = node.Step;
                node.Step = new NumberNode { Value = 1.0 };
            }

            return node;
        }

        private AstNode ParseWhile()
        {
            var node = new WhileNode();
            NextToken();
            node.Condition = ParseExpression();

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            node.Body = ParseBlock();
            return node;
        }

        private AstNode ParseReturn()
        {
            var node = new ReturnNode();
            NextToken();
            node.Value = ParseExpression();
            return node;
        }

        private AstNode ParseCoroutine()
        {
            return ParseMethod();
        }

        private AstNode ParseShader()
        {
            var node = new ShaderNode();
            NextToken();

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Name = curToken.Literal;

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            // Parse shader body
            while (!CurIs(TokenType.RBRACE) && !CurIs(TokenType.EOF))
            {
                if (CurIs(TokenType.PROPERTIES))
                {
                    NextToken();
                    if (!ExpectPeek(TokenType.LBRACE)) continue;
                    NextToken();
                    while (!CurIs(TokenType.RBRACE))
                    {
                        // Parse property
                        NextToken();
                    }
                }
                else if (CurIs(TokenType.SUBSHADER))
                {
                    // Parse subshader
                }
                NextToken();
            }

            return node;
        }

        private AstNode ParseXmlMessage()
        {
            var node = new XmlMessageNode();
            NextToken();

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.MessageType = curToken.Literal;

            if (!ExpectPeek(TokenType.LBRACE)) return null;
            NextToken();

            // Parse XML attributes
            while (!CurIs(TokenType.RBRACE) && !CurIs(TokenType.EOF))
            {
                if (CurIs(TokenType.IDENT))
                {
                    string key = curToken.Literal;
                    NextToken();
                    if (CurIs(TokenType.ASSIGN))
                    {
                        NextToken();
                        node.Attributes[key] = curToken.Literal;
                    }
                }
                NextToken();
            }

            return node;
        }

        private AstNode ParseWasmImport()
        {
            var node = new WasmImportNode();
            NextToken();

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Module = curToken.Literal;

            if (!ExpectPeek(TokenType.IDENT)) return null;
            node.Name = curToken.Literal;

            if (!ExpectPeek(TokenType.LPAREN)) return null;
            // Parse signature
            ExpectPeek(TokenType.RPAREN);

            return node;
        }

        private AstNode ParseExpressionStatement()
        {
            return ParseExpression();
        }

        private AstNode ParseExpression()
        {
            return ParseBinaryExpression(0);
        }

        private AstNode ParseBinaryExpression(int precedence)
        {
            AstNode left = ParseUnaryExpression();

            while (IsBinaryOperator(peekToken.Type) && GetPrecedence(peekToken.Type) > precedence)
            {
                NextToken();
                string op = curToken.Literal;
                AstNode right = ParseBinaryExpression(GetPrecedence(curToken.Type));
                left = new BinaryOpNode { Operator = op, Left = left, Right = right };
            }

            return left;
        }

        private AstNode ParseUnaryExpression()
        {
            if (CurIs(TokenType.MINUS) || CurIs(TokenType.BANG) || 
                CurIs(TokenType.DOLLAR) || CurIs(TokenType.AT))
            {
                string op = curToken.Literal;
                NextToken();
                return new UnaryOpNode { Operator = op, Operand = ParseUnaryExpression() };
            }
            return ParsePrimaryExpression();
        }

        private AstNode ParsePrimaryExpression()
        {
            return curToken.Type switch
            {
                TokenType.NUMBER => new NumberNode { Value = double.Parse(curToken.Literal) },
                TokenType.STRING => new StringNode { Value = curToken.Literal },
                TokenType.IDENT => ParseIdentifierOrCall(),
                TokenType.LPAREN => ParseGroupedExpression(),
                TokenType.LBRACKET => ParseMatrix(),
                TokenType.VEC3 => ParseVec3(),
                _ => new IdentifierNode { Name = curToken.Literal }
            };
        }

        private AstNode ParseIdentifierOrCall()
        {
            string name = curToken.Literal;

            if (PeekIs(TokenType.LPAREN))
            {
                return ParseCall(name);
            }
            else if (PeekIs(TokenType.DOT))
            {
                return ParseMemberAccess(new IdentifierNode { Name = name });
            }

            return new IdentifierNode { Name = name };
        }

        private AstNode ParseCall(string name)
        {
            var node = new CallNode { Function = new IdentifierNode { Name = name } };
            NextToken(); // consume (
            node.Arguments = ParseArguments();
            return node;
        }

        private List<AstNode> ParseArguments()
        {
            var args = new List<AstNode>();

            if (PeekIs(TokenType.RPAREN))
            {
                NextToken();
                return args;
            }

            NextToken();
            args.Add(ParseExpression());

            while (PeekIs(TokenType.COMMA))
            {
                NextToken();
                NextToken();
                args.Add(ParseExpression());
            }

            ExpectPeek(TokenType.RPAREN);
            return args;
        }

        private AstNode ParseMemberAccess(AstNode obj)
        {
            var node = new MemberAccessNode { Object = obj };
            NextToken(); // consume .
            NextToken();
            node.Member = curToken.Literal;

            if (PeekIs(TokenType.LPAREN))
            {
                // Method call on object
                return ParseCallOnObject(node);
            }

            return node;
        }

        private AstNode ParseCallOnObject(MemberAccessNode member)
        {
            var call = new CallNode { Function = member };
            NextToken();
            call.Arguments = ParseArguments();
            return call;
        }

        private AstNode ParseGroupedExpression()
        {
            NextToken();
            var expr = ParseExpression();
            ExpectPeek(TokenType.RPAREN);
            return expr;
        }

        private AstNode ParseMatrix()
        {
            var node = new MatrixNode();
            // Parse matrix literal [1,2;3,4]
            // Implementation...
            return node;
        }

        private AstNode ParseVec3()
        {
            var node = new Vec3Node();
            NextToken();
            if (!ExpectPeek(TokenType.LPAREN)) return null;
            NextToken();
            node.X = ParseExpression();
            ExpectPeek(TokenType.COMMA);
            NextToken();
            node.Y = ParseExpression();
            ExpectPeek(TokenType.COMMA);
            NextToken();
            node.Z = ParseExpression();
            ExpectPeek(TokenType.RPAREN);
            return node;
        }

        private bool IsBinaryOperator(TokenType t)
        {
            return t == TokenType.PLUS || t == TokenType.MINUS || 
                   t == TokenType.STAR || t == TokenType.SLASH ||
                   t == TokenType.CARET || t == TokenType.BANG ||
                   t == TokenType.DOTSTAR || t == TokenType.DOTSLASH ||
                   t == TokenType.DOTCARET || t == TokenType.EQ ||
                   t == TokenType.NE || t == TokenType.LT ||
                   t == TokenType.GT || t == TokenType.LE ||
                   t == TokenType.GE || t == TokenType.AND ||
                   t == TokenType.OR || t == TokenType.TILDE;
        }

        private int GetPrecedence(TokenType t)
        {
            return t switch
            {
                TokenType.OR => 1,
                TokenType.AND => 2,
                TokenType.EQ or TokenType.NE => 3,
                TokenType.LT or TokenType.GT or TokenType.LE or TokenType.GE => 4,
                TokenType.PLUS or TokenType.MINUS => 5,
                TokenType.STAR or TokenType.SLASH or TokenType.CARET or 
                TokenType.BANG or TokenType.DOTSTAR or TokenType.DOTSLASH or 
                TokenType.DOTCARET => 6,
                TokenType.TILDE => 7,
                _ => 0
            };
        }
    }
}