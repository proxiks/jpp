// ============================================================
// J++ → XML CODEGEN - C#
// Generates intermediate XML for Lua/C#/WASM split
// BSD-2-Clause License
// ============================================================

using System;
using System.Collections.Generic;
using System.Xml.Linq;

namespace Jpp.Unity
{
    public class XmlCodegen
    {
        public XDocument Generate(ProgramNode ast)
        {
            var root = new XElement("jpp-unity",
                new XAttribute("version", "1.0"),
                new XAttribute("generated", DateTime.Now.ToString("O"))
            );

            foreach (var stmt in ast.Statements)
            {
                root.Add(ConvertNode(stmt));
            }

            return new XDocument(root);
        }

        private XElement ConvertNode(AstNode node)
        {
            return node switch
            {
                IncludeNode inc => new XElement("include",
                    new XAttribute("module", inc.Module)),

                MaqNode maq => new XElement("macro-qualifier",
                    new XAttribute("domain", maq.Domain)),

                GameClassNode game => ConvertGameClass(game),

                FormulaNode formula => ConvertFormula(formula),

                MethodNode method => ConvertMethod(method),

                LetNode let => new XElement("variable",
                    new XAttribute("name", let.Name),
                    new XElement("value", ConvertExpression(let.Value))),

                ShaderNode shader => ConvertShader(shader),

                XmlMessageNode xml => ConvertXmlMessage(xml),

                WasmImportNode wasm => new XElement("wasm-import",
                    new XAttribute("module", wasm.Module),
                    new XAttribute("name", wasm.Name)),

                _ => new XElement("unknown")
            };
        }

        private XElement ConvertGameClass(GameClassNode game)
        {
            var elem = new XElement("game-class",
                new XAttribute("name", game.Name),
                new XAttribute("base", game.BaseClass ?? "MonoBehaviour")
            );

            // Split into modules
            var physicsGroup = new XElement("physics-module", new XAttribute("lang", "lua"));
            var uiGroup = new XElement("ui-module", new XAttribute("lang", "csharp"));
            var networkGroup = new XElement("network-module", new XAttribute("protocol", "xml"));

            foreach (var field in game.Fields)
            {
                var fieldElem = new XElement("field",
                    new XAttribute("access", field.AccessModifier),
                    new XAttribute("name", field.Name),
                    new XAttribute("type", field.Type)
                );

                if (field.Initializer != null)
                {
                    fieldElem.Add(new XElement("initializer", ConvertExpression(field.Initializer)));
                }

                // Route to appropriate module
                if (IsPhysicsType(field.Type))
                    physicsGroup.Add(fieldElem);
                else if (IsUIType(field.Type))
                    uiGroup.Add(fieldElem);
                else
                    elem.Add(fieldElem);
            }

            foreach (var method in game.Methods)
            {
                var methodElem = ConvertMethod(method);

                // Route by method name and attributes
                if (method.Attributes.Contains("SyncVar") || 
                    method.Attributes.Contains("Command") ||
                    method.Attributes.Contains("ClientRpc"))
                {
                    networkGroup.Add(methodElem);
                }
                else if (IsPhysicsMethod(method.Name))
                {
                    physicsGroup.Add(methodElem);
                }
                else if (IsUIMethod(method.Name))
                {
                    uiGroup.Add(methodElem);
                }
                else
                {
                    elem.Add(methodElem);
                }
            }

            if (physicsGroup.HasElements) elem.Add(physicsGroup);
            if (uiGroup.HasElements) elem.Add(uiGroup);
            if (networkGroup.HasElements) elem.Add(networkGroup);

            return elem;
        }

        private XElement ConvertMethod(MethodNode method)
        {
            var elem = new XElement("method",
                new XAttribute("name", method.Name),
                new XAttribute("return", method.ReturnType ?? "void"),
                new XAttribute("coroutine", method.IsCoroutine)
            );

            foreach (var attr in method.Attributes)
            {
                elem.Add(new XElement("attribute", attr));
            }

            foreach (var param in method.Parameters)
            {
                elem.Add(new XElement("parameter",
                    new XAttribute("name", param.Name),
                    new XAttribute("type", param.Type)));
            }

            foreach (var stmt in method.Body)
            {
                elem.Add(ConvertStatement(stmt));
            }

            return elem;
        }

        private XElement ConvertFormula(FormulaNode formula)
        {
            var elem = new XElement("formula",
                new XAttribute("name", formula.Name ?? "anonymous"),
                new XAttribute("target", formula.Target ?? "none"),
                new XAttribute("module", "lua")
            );

            foreach (var stmt in formula.Body)
            {
                elem.Add(ConvertStatement(stmt));
            }

            return elem;
        }

        private XElement ConvertShader(ShaderNode shader)
        {
            return new XElement("shader",
                new XAttribute("name", shader.Name),
                new XAttribute("module", "lua"),
                new XElement("properties"),
                new XElement("subshaders")
            );
        }

        private XElement ConvertXmlMessage(XmlMessageNode xml)
        {
            var elem = new XElement("network-message",
                new XAttribute("type", xml.MessageType));

            foreach (var attr in xml.Attributes)
            {
                elem.Add(new XElement("attribute",
                    new XAttribute("name", attr.Key),
                    new XAttribute("value", attr.Value)));
            }

            return elem;
        }

        private XElement ConvertStatement(AstNode stmt)
        {
            return stmt switch
            {
                LetNode let => new XElement("assign",
                    new XAttribute("var", let.Name),
                    ConvertExpression(let.Value)),

                IfNode ifn => new XElement("if",
                    new XElement("condition", ConvertExpression(ifn.Condition)),
                    new XElement("then", ifn.ThenBody.ConvertAll(ConvertStatement)),
                    new XElement("else", ifn.ElseBody.ConvertAll(ConvertStatement))),

                ForNode fn => new XElement("for",
                    new XAttribute("iterator", fn.Iterator),
                    new XElement("range", ConvertExpression(fn.Range)),
                    new XElement("body", fn.Body.ConvertAll(ConvertStatement))),

                WhileNode wn => new XElement("while",
                    new XElement("condition", ConvertExpression(wn.Condition)),
                    new XElement("body", wn.Body.ConvertAll(ConvertStatement))),

                ReturnNode rn => new XElement("return",
                    ConvertExpression(rn.Value)),

                CallNode cn => new XElement("call",
                    ConvertExpression(cn.Function),
                    new XElement("args", cn.Arguments.ConvertAll(ConvertExpression))),

                YieldNode yn => new XElement("yield",
                    new XAttribute("type", yn.YieldType),
                    ConvertExpression(yn.Value)),

                _ => new XElement("statement", stmt.GetType().Name)
            };
        }

        private XElement ConvertExpression(AstNode expr)
        {
            return expr switch
            {
                NumberNode n => new XElement("number", n.Value),
                StringNode s => new XElement("string", s.Value),
                IdentifierNode i => new XElement("ident", i.Name),
                BinaryOpNode b => new XElement("binary",
                    new XAttribute("op", b.Operator),
                    ConvertExpression(b.Left),
                    ConvertExpression(b.Right)),
                UnaryOpNode u => new XElement("unary",
                    new XAttribute("op", u.Operator),
                    ConvertExpression(u.Operand)),
                Vec3Node v => new XElement("vec3",
                    ConvertExpression(v.X),
                    ConvertExpression(v.Y),
                    ConvertExpression(v.Z)),
                MemberAccessNode m => new XElement("member-access",
                    ConvertExpression(m.Object),
                    new XAttribute("member", m.Member)),
                CallNode c => new XElement("call",
                    ConvertExpression(c.Function),
                    new XElement("args", c.Arguments.ConvertAll(ConvertExpression))),
                _ => new XElement("expr", expr.GetType().Name)
            };
        }

        private bool IsPhysicsType(string type) =>
            type is "Rigidbody" or "Collider" or "ForceMode" or "vec3" or "vec4" or
                   "mat3" or "mat4" or "ParticleSystem";

        private bool IsUIType(string type) =>
            type is "Canvas" or "Button" or "Slider" or "Text" or "Image" or "Panel";

        private bool IsPhysicsMethod(string name) =>
            name is "FixedUpdate" or "OnCollisionEnter" or "OnCollisionExit" or
                   "OnTriggerEnter" or "AddForce" or "MovePosition";

        private bool IsUIMethod(string name) =>
            name is "OnGUI" or "UpdateUI" or "ShowMenu" or "HideMenu";
    }
}