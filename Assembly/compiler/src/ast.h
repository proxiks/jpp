#include "ast.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

/* ========================================================================
 * J++ COMPILER - ABSTRACT SYNTAX TREE IMPLEMENTATION
 * Complete AST node construction, traversal, and memory management
 * ======================================================================== */

AstNode *ast_new_node(AstNodeType type) {
    AstNode *node = calloc(1, sizeof(AstNode));
    if (!node) {
        fprintf(stderr, "FATAL: Out of memory in ast_new_node\n");
        exit(1);
    }
    node->type = type;
    node->line = 0;
    node->column = 0;
    node->jpp_type = NULL;
    node->parent = NULL;
    node->children = NULL;
    node->child_count = 0;
    return node;
}

AstNode *ast_int_literal(long long val, int line, int col) {
    AstNode *node = ast_new_node(AST_INT_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_int;
    node->data.int_literal.int_val = val;
    return node;
}

AstNode *ast_float_literal(double val, int line, int col) {
    AstNode *node = ast_new_node(AST_FLOAT_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_double;
    node->data.float_literal.float_val = val;
    return node;
}

AstNode *ast_string_literal(const char *val, int line, int col) {
    AstNode *node = ast_new_node(AST_STRING_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_string;
    node->data.string_literal.str_val = strdup(val ? val : "");
    return node;
}

AstNode *ast_char_literal(char val, int line, int col) {
    AstNode *node = ast_new_node(AST_CHAR_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_char;
    node->data.char_literal.char_val = val;
    return node;
}

AstNode *ast_bool_literal(bool val, int line, int col) {
    AstNode *node = ast_new_node(AST_BOOL_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_bool;
    node->data.bool_literal.bool_val = val;
    return node;
}

AstNode *ast_null_literal(int line, int col) {
    AstNode *node = ast_new_node(AST_NULL_LITERAL);
    node->line = line; node->column = col;
    node->jpp_type = type_pointer_to(jpp_type_void);
    return node;
}

AstNode *ast_identifier(const char *name, int line, int col) {
    AstNode *node = ast_new_node(AST_IDENTIFIER);
    node->line = line; node->column = col;
    node->data.identifier.name = strdup(name ? name : "<unknown>");
    node->data.identifier.symbol = NULL;
    return node;
}

AstNode *ast_binary_expr(const char *op, AstNode *left, AstNode *right, int line, int col) {
    AstNode *node = ast_new_node(AST_BINARY_EXPR);
    node->line = line; node->column = col;
    node->data.binary.op = strdup(op ? op : "?");
    node->data.binary.left = left;
    node->data.binary.right = right;
    if (left) ast_add_child(node, left);
    if (right) ast_add_child(node, right);
    return node;
}

AstNode *ast_unary_expr(const char *op, AstNode *operand, int line, int col) {
    AstNode *node = ast_new_node(AST_UNARY_EXPR);
    node->line = line; node->column = col;
    node->data.unary.op = strdup(op ? op : "?");
    node->data.unary.operand = operand;
    if (operand) ast_add_child(node, operand);
    return node;
}

AstNode *ast_ternary_expr(AstNode *cond, AstNode *true_expr, AstNode *false_expr, int line, int col) {
    AstNode *node = ast_new_node(AST_TERNARY_EXPR);
    node->line = line; node->column = col;
    node->data.ternary.cond = cond;
    node->data.ternary.true_expr = true_expr;
    node->data.ternary.false_expr = false_expr;
    if (cond) ast_add_child(node, cond);
    if (true_expr) ast_add_child(node, true_expr);
    if (false_expr) ast_add_child(node, false_expr);
    return node;
}

AstNode *ast_address_of(AstNode *operand, int line, int col) {
    AstNode *node = ast_new_node(AST_ADDRESS_OF);
    node->line = line; node->column = col;
    if (operand) ast_add_child(node, operand);
    return node;
}

AstNode *ast_dereference(AstNode *operand, int line, int col) {
    AstNode *node = ast_new_node(AST_DEREFERENCE);
    node->line = line; node->column = col;
    if (operand) ast_add_child(node, operand);
    return node;
}

AstNode *ast_pointer_decl(JppType *base_type, const char *name, AstNode *init, int line, int col) {
    AstNode *node = ast_new_node(AST_POINTER_DECL);
    node->line = line; node->column = col;
    node->jpp_type = type_pointer_to(base_type);
    node->data.var_decl.var_type = node->jpp_type;
    node->data.var_decl.var_name = strdup(name ? name : "<ptr>");
    node->data.var_decl.init_expr = init;
    if (init) ast_add_child(node, init);
    return node;
}

AstNode *ast_var_decl(JppType *type, const char *name, AstNode *init, int line, int col) {
    AstNode *node = ast_new_node(AST_VAR_DECL);
    node->line = line; node->column = col;
    node->jpp_type = type;
    node->data.var_decl.var_type = type;
    node->data.var_decl.var_name = strdup(name ? name : "<anon>");
    node->data.var_decl.init_expr = init;
    node->data.var_decl.is_const = false;
    node->data.var_decl.is_static = false;
    node->data.var_decl.is_extern = false;
    if (init) ast_add_child(node, init);
    return node;
}

AstNode *ast_const_var_decl(JppType *type, const char *name, AstNode *init, int line, int col) {
    AstNode *node = ast_var_decl(type, name, init, line, col);
    node->data.var_decl.is_const = true;
    if (type) {
        node->jpp_type = type_add_qualifier(type, QUAL_CONST);
        node->data.var_decl.var_type = node->jpp_type;
    }
    return node;
}

AstNode *ast_static_var_decl(JppType *type, const char *name, AstNode *init, int line, int col) {
    AstNode *node = ast_var_decl(type, name, init, line, col);
    node->data.var_decl.is_static = true;
    return node;
}

AstNode *ast_extern_var_decl(JppType *type, const char *name, int line, int col) {
    AstNode *node = ast_var_decl(type, name, NULL, line, col);
    node->data.var_decl.is_extern = true;
    return node;

AstNode *ast_function_def(JppType *ret_type, const char *name, 
                          AstNode **params, int param_count, 
                          AstNode *body, int line, int col) {
    AstNode *node = ast_new_node(AST_FUNCTION_DEF);
    node->line = line; node->column = col;
    node->data.function.return_type = ret_type;
    node->data.function.func_name = strdup(name ? name : "<anon_func>");
    node->data.function.params = params;
    node->data.function.param_count = param_count;
    node->data.function.body = body;
    node->data.function.is_inline = false;
    
    JppType **param_types = NULL;
    if (param_count > 0) {
        param_types = malloc(param_count * sizeof(JppType *));
        for (int i = 0; i < param_count; i++) {
            if (params[i] && params[i]->type == AST_VAR_DECL) {
                param_types[i] = params[i]->data.var_decl.var_type;
            } else {
                param_types[i] = jpp_type_void;
            }
            ast_add_child(node, params[i]);
        }
    }
    
    node->jpp_type = type_function_returning(ret_type, param_types, param_count);
    if (param_types) free(param_types);
    
    if (body) ast_add_child(node, body);
    return node;
}

AstNode *ast_inline_function_def(JppType *ret_type, const char *name,
                                  AstNode **params, int param_count,
                                  AstNode *body, int line, int col) {
    AstNode *node = ast_function_def(ret_type, name, params, param_count, body, line, col);
    node->data.function.is_inline = true;
    return node;
}

AstNode *ast_function_decl(JppType *ret_type, const char *name,
                           AstNode **params, int param_count, int line, int col) {
    AstNode *node = ast_new_node(AST_FUNCTION_DECL);
    node->line = line; node->column = col;
    node->data.function.return_type = ret_type;
    node->data.function.func_name = strdup(name ? name : "<anon>");
    node->data.function.params = params;
    node->data.function.param_count = param_count;
    node->data.function.body = NULL;
    node->data.function.is_inline = false;
    
    JppType **param_types = NULL;
    if (param_count > 0) {
        param_types = malloc(param_count * sizeof(JppType *));
        for (int i = 0; i < param_count; i++) {
            if (params[i] && params[i]->type == AST_VAR_DECL) {
                param_types[i] = params[i]->data.var_decl.var_type;
            } else {
                param_types[i] = jpp_type_void;
            }
            ast_add_child(node, params[i]);
        }
    }
    
    node->jpp_type = type_function_returning(ret_type, param_types, param_count);
    if (param_types) free(param_types);
    return node;
}

AstNode *ast_block(AstNode **stmts, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_BLOCK);
    node->line = line; node->column = col;
    node->data.block.stmts = stmts;
    node->data.block.stmt_count = count;
    for (int i = 0; i < count; i++) {
        if (stmts[i]) ast_add_child(node, stmts[i]);
    }
    return node;
}

AstNode *ast_empty_block(int line, int col) {
    return ast_block(NULL, 0, line, col);
}

AstNode *ast_if_stmt(AstNode *cond, AstNode *then_branch, AstNode *else_branch, int line, int col) {
    AstNode *node = ast_new_node(AST_IF_STMT);
    node->line = line; node->column = col;
    node->data.if_stmt.condition = cond;
    node->data.if_stmt.then_branch = then_branch;
    node->data.if_stmt.else_branch = else_branch;
    if (cond) ast_add_child(node, cond);
    if (then_branch) ast_add_child(node, then_branch);
    if (else_branch) ast_add_child(node, else_branch);
    return node;
}

AstNode *ast_for_stmt(AstNode *init, AstNode *cond, AstNode *inc, AstNode *body, int line, int col) {
    AstNode *node = ast_new_node(AST_FOR_STMT);
    node->line = line; node->column = col;
    node->data.for_stmt.init = init;
    node->data.for_stmt.condition = cond;
    node->data.for_stmt.increment = inc;
    node->data.for_stmt.body = body;
    if (init) ast_add_child(node, init);
    if (cond) ast_add_child(node, cond);
    if (inc) ast_add_child(node, inc);
    if (body) ast_add_child(node, body);
    return node;
}

AstNode *ast_while_stmt(AstNode *cond, AstNode *body, int line, int col) {
    AstNode *node = ast_new_node(AST_WHILE_STMT);
    node->line = line; node->column = col;
    node->data.while_stmt.condition = cond;
    node->data.while_stmt.body = body;
    if (cond) ast_add_child(node, cond);
    if (body) ast_add_child(node, body);
    return node;
}

AstNode *ast_do_while_stmt(AstNode *body, AstNode *cond, int line, int col) {
    AstNode *node = ast_new_node(AST_DO_WHILE_STMT);
    node->line = line; node->column = col;
    node->data.do_while.body = body;
    node->data.do_while.condition = cond;
    if (body) ast_add_child(node, body);
    if (cond) ast_add_child(node, cond);
    return node;
}

AstNode *ast_switch_stmt(AstNode *expr, AstNode **cases, int case_count, int line, int col) {
    AstNode *node = ast_new_node(AST_SWITCH_STMT);
    node->line = line; node->column = col;
    node->data.switch_stmt.expr = expr;
    node->data.switch_stmt.cases = cases;
    node->data.switch_stmt.case_count = case_count;
    if (expr) ast_add_child(node, expr);
    for (int i = 0; i < case_count; i++) {
        if (cases[i]) ast_add_child(node, cases[i]);
    }
    return node;
}

AstNode *ast_case_label(AstNode *value, AstNode *stmt, int line, int col) {
    AstNode *node = ast_new_node(AST_CASE_LABEL);
    node->line = line; node->column = col;
    if (value) ast_add_child(node, value);
    if (stmt) ast_add_child(node, stmt);
    return node;
}

AstNode *ast_default_label(AstNode *stmt, int line, int col) {
    AstNode *node = ast_new_node(AST_DEFAULT_LABEL);
    node->line = line; node->column = col;
    if (stmt) ast_add_child(node, stmt);
    return node;
}

AstNode *ast_return_stmt(AstNode *expr, int line, int col) {
    AstNode *node = ast_new_node(AST_RETURN_STMT);
    node->line = line; node->column = col;
    node->data.return_stmt.expr = expr;
    if (expr) ast_add_child(node, expr);
    return node;
}

AstNode *ast_break_stmt(int line, int col) {
    AstNode *node = ast_new_node(AST_BREAK_STMT);
    node->line = line; node->column = col;
    return node;
}

AstNode *ast_continue_stmt(int line, int col) {
    AstNode *node = ast_new_node(AST_CONTINUE_STMT);
    node->line = line; node->column = col;
    return node;
}

AstNode *ast_goto_stmt(const char *label, int line, int col) {
    AstNode *node = ast_new_node(AST_GOTO_STMT);
    node->line = line; node->column = col;
    node->data.goto_stmt.label_name = strdup(label ? label : "<unknown>");
    return node;
}

AstNode *ast_label(const char *name, AstNode *stmt, int line, int col) {
    AstNode *node = ast_new_node(AST_LABEL);
    node->line = line; node->column = col;
    node->data.label.label_name = strdup(name ? name : "<unknown>");
    node->data.label.stmt = stmt;
    if (stmt) ast_add_child(node, stmt);
    return node;
}

AstNode *ast_expr_stmt(AstNode *expr, int line, int col) {
    AstNode *node = ast_new_node(AST_EXPR_STMT);
    node->line = line; node->column = col;
    if (expr) ast_add_child(node, expr);
    return node;
}

AstNode *ast_empty_stmt(int line, int col) {
    AstNode *node = ast_new_node(AST_EMPTY_STMT);
    node->line = line; node->column = col;
    return node;
}

AstNode *ast_function_call(AstNode *func, AstNode **args, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_FUNCTION_CALL);
    node->line = line; node->column = col;
    node->data.call.func = func;
    node->data.call.args = args;
    node->data.call.arg_count = count;
    if (func) ast_add_child(node, func);
    for (int i = 0; i < count; i++) {
        if (args[i]) ast_add_child(node, args[i]);
    }
    return node;
}

AstNode *ast_array_access(AstNode *array, AstNode *index, int line, int col) {
    AstNode *node = ast_new_node(AST_ARRAY_ACCESS);
    node->line = line; node->column = col;
    node->data.array_access.array = array;
    node->data.array_access.index = index;
    if (array) ast_add_child(node, array);
    if (index) ast_add_child(node, index);
    return node;
}

AstNode *ast_member_access(AstNode *obj, const char *member, bool is_pointer, int line, int col) {
    AstNode *node = ast_new_node(is_pointer ? AST_POINTER_ACCESS : AST_MEMBER_ACCESS);
    node->line = line; node->column = col;
    node->data.member.object = obj;
    node->data.member.member_name = strdup(member ? member : "<unknown>");
    if (obj) ast_add_child(node, obj);
    return node;
}

AstNode *ast_cast_expr(JppType *type, AstNode *expr, int line, int col) {
    AstNode *node = ast_new_node(AST_CAST_EXPR);
    node->line = line; node->column = col;
    node->data.cast.target_type = type;
    node->data.cast.expr = expr;
    if (expr) ast_add_child(node, expr);
    return node;
}

AstNode *ast_sizeof_expr(AstNode *expr, int line, int col) {
    AstNode *node = ast_new_node(AST_SIZEOF_EXPR);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_ulong_long;
    if (expr) ast_add_child(node, expr);
    return node;
}

AstNode *ast_sizeof_type(JppType *type, int line, int col) {
    AstNode *node = ast_new_node(AST_SIZEOF_EXPR);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_ulong_long;
    node->data.type_name.type = type;
    return node;
}

AstNode *ast_comma_expr(AstNode **exprs, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_COMMA_EXPR);
    node->line = line; node->column = col;
    for (int i = 0; i < count; i++) {
        if (exprs[i]) ast_add_child(node, exprs[i]);
    }
    return node;
}

AstNode *ast_printel_call(const char *format, AstNode **args, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_PRINTEL_CALL);
    node->line = line; node->column = col;
    node->data.printel.format = strdup(format ? format : "");
    node->data.printel.args = args;
    node->data.printel.arg_count = count;
    for (int i = 0; i < count; i++) {
        if (args[i]) ast_add_child(node, args[i]);
    }
    return node;
}

AstNode *ast_scanel_call(const char *format, AstNode **args, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_SCANEL_CALL);
    node->line = line; node->column = col;
    node->data.scanel.format = strdup(format ? format : "");
    node->data.scanel.args = args;
    node->data.scanel.arg_count = count;
    for (int i = 0; i < count; i++) {
        if (args[i]) ast_add_child(node, args[i]);
    }
    return node;
}

AstNode *ast_timer_stmt(AstNode *start_expr, AstNode *end_expr, AstNode *body, int line, int col) {
    AstNode *node = ast_new_node(AST_TIMER_STMT);
    node->line = line; node->column = col;
    node->data.timer.start = start_expr;
    node->data.timer.end = end_expr;
    node->data.timer.body = body;
    if (start_expr) ast_add_child(node, start_expr);
    if (end_expr) ast_add_child(node, end_expr);
    if (body) ast_add_child(node, body);
    return node;
}

AstNode *ast_array_decl(JppType *elem_type, int size, const char *name, 
                         AstNode **init_values, int init_count, int line, int col) {
    AstNode *node = ast_new_node(AST_ARRAY_DECL);
    node->line = line; node->column = col;
    node->jpp_type = type_array_of(elem_type, size);
    node->data.var_decl.var_type = node->jpp_type;
    node->data.var_decl.var_name = strdup(name ? name : "<arr>");
    
    if (init_count > 0 && init_values) {
        AstNode *init = ast_new_node(AST_ARRAY_INIT);
        init->line = line; init->column = col;
        for (int i = 0; i < init_count; i++) {
            if (init_values[i]) ast_add_child(init, init_values[i]);
        }
        node->data.var_decl.init_expr = init;
        ast_add_child(node, init);
    }
    return node;
}

AstNode *ast_array_init(AstNode **values, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_ARRAY_INIT);
    node->line = line; node->column = col;
    for (int i = 0; i < count; i++) {
        if (values[i]) ast_add_child(node, values[i]);
    }
    return node;
}

AstNode *ast_struct_def(const char *name, AstNode **fields, int field_count, int line, int col) {
    AstNode *node = ast_new_node(AST_STRUCT_DEF);
    node->line = line; node->column = col;
    node->data.struct_def.name = strdup(name ? name : "<anon_struct>");
    node->data.struct_def.members = fields;
    node->data.struct_def.member_count = field_count;
    
    JppType *struct_type = type_new(TYPE_STRUCT);
    struct_type->struct_name = strdup(node->data.struct_def.name);
    struct_type->field_count = field_count;
    if (field_count > 0) {
        struct_type->fields = calloc(field_count, sizeof(JppStructField));
        for (int i = 0; i < field_count; i++) {
            if (fields[i] && fields[i]->type == AST_VAR_DECL) {
                struct_type->fields[i].name = strdup(fields[i]->data.var_decl.var_name);
                struct_type->fields[i].type = fields[i]->data.var_decl.var_type;
            }
            ast_add_child(node, fields[i]);
        }
    }
    node->jpp_type = struct_type;
    return node;
}

AstNode *ast_union_def(const char *name, AstNode **fields, int field_count, int line, int col) {
    AstNode *node = ast_new_node(AST_UNION_DEF);
    node->line = line; node->column = col;
    node->data.struct_def.name = strdup(name ? name : "<anon_union>");
    node->data.struct_def.members = fields;
    node->data.struct_def.member_count = field_count;
    
    JppType *union_type = type_new(TYPE_UNION);
    union_type->struct_name = strdup(node->data.struct_def.name);
    union_type->field_count = field_count;
    if (field_count > 0) {
        union_type->fields = calloc(field_count, sizeof(JppStructField));
        for (int i = 0; i < field_count; i++) {
            if (fields[i] && fields[i]->type == AST_VAR_DECL) {
                union_type->fields[i].name = strdup(fields[i]->data.var_decl.var_name);
                union_type->fields[i].type = fields[i]->data.var_decl.var_type;
            }
            ast_add_child(node, fields[i]);
        }
    }
    node->jpp_type = union_type;
    return node;
}

AstNode *ast_enum_def(const char *name, char **constants, int *values, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_ENUM_DEF);
    node->line = line; node->column = col;
    node->jpp_type = jpp_type_int;
    node->data.struct_def.name = strdup(name ? name : "<anon_enum>");
    return node;
}

AstNode *ast_typedef(JppType *type, const char *alias, int line, int col) {
    AstNode *node = ast_new_node(AST_TYPEDEF);
    node->line = line; node->column = col;
    node->data.type_name.type = type;
    node->data.identifier.name = strdup(alias ? alias : "<alias>");
    return node;
}

AstNode *ast_include(const char *header, bool is_system, int line, int col) {
    AstNode *node = ast_new_node(AST_INCLUDE);
    node->line = line; node->column = col;
    node->data.include.header_name = strdup(header ? header : "");
    node->data.include.is_system = is_system;
    return node;
}

AstNode *ast_define(const char *name, const char *replacement, int line, int col) {
    AstNode *node = ast_new_node(AST_DEFINE);
    node->line = line; node->column = col;
    node->data.define.macro_name = strdup(name ? name : "");
    node->data.define.replacement = strdup(replacement ? replacement : "");
    return node;
}

AstNode *ast_ifdef(const char *macro, int line, int col) {
    AstNode *node = ast_new_node(AST_IFDEF);
    node->line = line; node->column = col;
    node->data.define.macro_name = strdup(macro ? macro : "");
    return node;
}

AstNode *ast_ifndef(const char *macro, int line, int col) {
    AstNode *node = ast_new_node(AST_IFNDEF);
    node->line = line; node->column = col;
    node->data.define.macro_name = strdup(macro ? macro : "");
    return node;
}

AstNode *ast_preproc_if(AstNode *cond, int line, int col) {
    AstNode *node = ast_new_node(AST_PREPROC_IF);
    node->line = line; node->column = col;
    if (cond) ast_add_child(node, cond);
    return node;
}

AstNode *ast_preproc_elif(AstNode *cond, int line, int col) {
    AstNode *node = ast_new_node(AST_PREPROC_ELIF);
    node->line = line; node->column = col;
    if (cond) ast_add_child(node, cond);
    return node;
}

AstNode *ast_preproc_else(int line, int col) {
    AstNode *node = ast_new_node(AST_PREPROC_ELSE);
    node->line = line; node->column = col;
    return node;
}

AstNode *ast_preproc_endif(int line, int col) {
    AstNode *node = ast_new_node(AST_PREPROC_ENDIF);
    node->line = line; node->column = col;
    return node;
}

AstNode *ast_program(AstNode **decls, int count, int line, int col) {
    AstNode *node = ast_new_node(AST_PROGRAM);
    node->line = line; node->column = col;
    node->data.program.declarations = decls;
    node->data.program.decl_count = count;
    for (int i = 0; i < count; i++) {
        if (decls[i]) ast_add_child(node, decls[i]);
    }
    return node;
}

AstNode *ast_type_name(JppType *type, int line, int col) {
    AstNode *node = ast_new_node(AST_TYPE_NAME);
    node->line = line; node->column = col;
    node->data.type_name.type = type;
    node->jpp_type = type;
    return node;
}

void ast_add_child(AstNode *parent, AstNode *child) {
    if (!parent || !child) return;
    parent->child_count++;
    parent->children = realloc(parent->children, parent->child_count * sizeof(AstNode *));
    parent->children[parent->child_count - 1] = child;
    child->parent = parent;
}

void ast_insert_child(AstNode *parent, AstNode *child, int index) {
    if (!parent || !child || index < 0 || index > parent->child_count) return;
    parent->child_count++;
    parent->children = realloc(parent->children, parent->child_count * sizeof(AstNode *));
    for (int i = parent->child_count - 1; i > index; i--) {
        parent->children[i] = parent->children[i - 1];
    }
    parent->children[index] = child;
    child->parent = parent;
}

void ast_remove_child(AstNode *parent, int index) {
    if (!parent || index < 0 || index >= parent->child_count) return;
    AstNode *child = parent->children[index];
    if (child) child->parent = NULL;
    for (int i = index; i < parent->child_count - 1; i++) {
        parent->children[i] = parent->children[i + 1];
    }
    parent->child_count--;
    if (parent->child_count > 0) {
        parent->children = realloc(parent->children, parent->child_count * sizeof(AstNode *));
    } else {
        free(parent->children);
        parent->children = NULL;
    }
}

AstNode *ast_get_child(AstNode *parent, int index) {
    if (!parent || index < 0 || index >= parent->child_count) return NULL;
    return parent->children[index];
}

int ast_child_index(AstNode *parent, AstNode *child) {
    if (!parent || !child) return -1;
    for (int i = 0; i < parent->child_count; i++) {
        if (parent->children[i] == child) return i;
    }
    return -1;
}

typedef void (*AstVisitorFunc)(AstNode *node, void *user_data);

void ast_visit_preorder(AstNode *node, AstVisitorFunc visitor, void *user_data) {
    if (!node || !visitor) return;
    visitor(node, user_data);
    for (int i = 0; i < node->child_count; i++) {
        ast_visit_preorder(node->children[i], visitor, user_data);
    }
}

void ast_visit_postorder(AstNode *node, AstVisitorFunc visitor, void *user_data) {
    if (!node || !visitor) return;
    for (int i = 0; i < node->child_count; i++) {
        ast_visit_postorder(node->children[i], visitor, user_data);
    }
    visitor(node, user_data);
}

typedef struct {
    AstNodeType target_type;
    AstNode **found;
    int count;
    int capacity;
} FindContext;

static void find_visitor(AstNode *node, void *user_data) {
    FindContext *ctx = (FindContext *)user_data;
    if (node->type == ctx->target_type) {
        if (ctx->count >= ctx->capacity) {
            ctx->capacity *= 2;
            ctx->found = realloc(ctx->found, ctx->capacity * sizeof(AstNode *));
        }
        ctx->found[ctx->count++] = node;
    }
}

AstNode **ast_find_nodes(AstNode *root, AstNodeType type, int *out_count) {
    FindContext ctx = {
        .target_type = type,
        .found = malloc(16 * sizeof(AstNode *)),
        .count = 0,
        .capacity = 16
    };
    ast_visit_preorder(root, find_visitor, &ctx);
    *out_count = ctx.count;
    return ctx.found;
}

AstNode *ast_find_first(AstNode *root, AstNodeType type) {
    int count;
    AstNode **found = ast_find_nodes(root, type, &count);
    AstNode *result = (count > 0) ? found[0] : NULL;
    free(found);
    return result;
}

AstNode *ast_find_function(AstNode *root, const char *name) {
    if (!root || !name) return NULL;
    int count;
    AstNode **funcs = ast_find_nodes(root, AST_FUNCTION_DEF, &count);
    AstNode *result = NULL;
    for (int i = 0; i < count; i++) {
        if (funcs[i]->data.function.func_name && 
            strcmp(funcs[i]->data.function.func_name, name) == 0) {
            result = funcs[i];
            break;
        }
    }
    free(funcs);
    return result;
}

AstNode *ast_find_variable(AstNode *scope, const char *name) {
    if (!scope || !name) return NULL;
    for (int i = 0; i < scope->child_count; i++) {
        AstNode *child = scope->children[i];
        if ((child->type == AST_VAR_DECL || child->type == AST_POINTER_DECL) &&
            child->data.var_decl.var_name &&
            strcmp(child->data.var_decl.var_name, name) == 0) {
            return child;
        }
    }
    if (scope->parent) {
        return ast_find_variable(scope->parent, name);
    }
    return NULL;
}

const char *ast_node_name(AstNodeType type) {
    switch (type) {
        case AST_PROGRAM: return "PROGRAM";
        case AST_FUNCTION_DEF: return "FUNCTION_DEF";
        case AST_FUNCTION_DECL: return "FUNCTION_DECL";
        case AST_BLOCK: return "BLOCK";
        case AST_VAR_DECL: return "VAR_DECL";
        case AST_ASSIGNMENT: return "ASSIGNMENT";
        case AST_IF_STMT: return "IF_STMT";
        case AST_FOR_STMT: return "FOR_STMT";
        case AST_WHILE_STMT: return "WHILE_STMT";
        case AST_DO_WHILE_STMT: return "DO_WHILE_STMT";
        case AST_SWITCH_STMT: return "SWITCH_STMT";
        case AST_CASE_LABEL: return "CASE_LABEL";
        case AST_DEFAULT_LABEL: return "DEFAULT_LABEL";
        case AST_BREAK_STMT: return "BREAK_STMT";
        case AST_CONTINUE_STMT: return "CONTINUE_STMT";
        case AST_RETURN_STMT: return "RETURN_STMT";
        case AST_GOTO_STMT: return "GOTO_STMT";
        case AST_LABEL: return "LABEL";
        case AST_EXPR_STMT: return "EXPR_STMT";
        case AST_EMPTY_STMT: return "EMPTY_STMT";
        case AST_BINARY_EXPR: return "BINARY_EXPR";
        case AST_UNARY_EXPR: return "UNARY_EXPR";
        case AST_TERNARY_EXPR: return "TERNARY_EXPR";
        case AST_LITERAL: return "LITERAL";
        case AST_IDENTIFIER: return "IDENTIFIER";
        case AST_ARRAY_ACCESS: return "ARRAY_ACCESS";
        case AST_FUNCTION_CALL: return "FUNCTION_CALL";
        case AST_MEMBER_ACCESS: return "MEMBER_ACCESS";
        case AST_POINTER_ACCESS: return "POINTER_ACCESS";
        case AST_CAST_EXPR: return "CAST_EXPR";
        case AST_SIZEOF_EXPR: return "SIZEOF_EXPR";
        case AST_COMMA_EXPR: return "COMMA_EXPR";
        case AST_PRINTEL_CALL: return "PRINTEL_CALL";
        case AST_SCANEL_CALL: return "SCANEL_CALL";
        case AST_TIMER_STMT: return "TIMER_STMT";
        case AST_TYPE_NAME: return "TYPE_NAME";
        case AST_STRUCT_DEF: return "STRUCT_DEF";
        case AST_UNION_DEF: return "UNION_DEF";
        case AST_ENUM_DEF: return "ENUM_DEF";
        case AST_TYPEDEF: return "TYPEDEF";
        case AST_ADDRESS_OF: return "ADDRESS_OF";
        case AST_DEREFERENCE: return "DEREFERENCE";
        case AST_POINTER_DECL: return "POINTER_DECL";
        case AST_ARRAY_DECL: return "ARRAY_DECL";
        case AST_ARRAY_INIT: return "ARRAY_INIT";
        case AST_INCLUDE: return "INCLUDE";
        case AST_DEFINE: return "DEFINE";
        case AST_IFDEF: return "IFDEF";
        case AST_IFNDEF: return "IFNDEF";
        case AST_PREPROC_IF: return "PREPROC_IF";
        case AST_PREPROC_ELIF: return "PREPROC_ELIF";
        case AST_PREPROC_ELSE: return "PREPROC_ELSE";
        case AST_PREPROC_ENDIF: return "PREPROC_ENDIF";
        case AST_STRING_LITERAL: return "STRING_LITERAL";
        case AST_CHAR_LITERAL: return "CHAR_LITERAL";
        case AST_INT_LITERAL: return "INT_LITERAL";
        case AST_FLOAT_LITERAL: return "FLOAT_LITERAL";
        case AST_BOOL_LITERAL: return "BOOL_LITERAL";
        case AST_NULL_LITERAL: return "NULL_LITERAL";
        default: return "UNKNOWN";
    }
}

static void ast_print_indent(int indent) {
    for (int i = 0; i < indent; i++) printf("  ");
}

static void ast_print_node_details(AstNode *node, int indent) {
    ast_print_indent(indent);
    printf("[%s", ast_node_name(node->type));
    if (node->line > 0) {
        printf(" @ %d:%d", node->line, node->column);
    }
    switch (node->type) {
        case AST_INT_LITERAL:
            printf(" val=%lld", node->data.int_literal.int_val);
            break;
        case AST_FLOAT_LITERAL:
            printf(" val=%.6f", node->data.float_literal.float_val);
            break;
        case AST_STRING_LITERAL:
            printf(" val=\"%s\"", node->data.string_literal.str_val ? node->data.string_literal.str_val : "");
            break;
        case AST_CHAR_LITERAL:
            printf(" val='%c'", node->data.char_literal.char_val);
            break;
        case AST_BOOL_LITERAL:
            printf(" val=%s", node->data.bool_literal.bool_val ? "true" : "false");
            break;
        case AST_IDENTIFIER:
            printf(" name='%s'", node->data.identifier.name ? node->data.identifier.name : "<null>");
            break;
        case AST_BINARY_EXPR:
            printf(" op='%s'", node->data.binary.op ? node->data.binary.op : "?");
            break;
        case AST_UNARY_EXPR:
            printf(" op='%s'", node->data.unary.op ? node->data.unary.op : "?");
            break;
        case AST_VAR_DECL:
        case AST_POINTER_DECL:
        case AST_ARRAY_DECL:
            printf(" name='%s'", node->data.var_decl.var_name ? node->data.var_decl.var_name : "<null>");
            if (node->data.var_decl.is_const) printf(" const");
            if (node->data.var_decl.is_static) printf(" static");
            if (node->data.var_decl.is_extern) printf(" extern");
            break;
        case AST_FUNCTION_DEF:
        case AST_FUNCTION_DECL:
            printf(" name='%s'", node->data.function.func_name ? node->data.function.func_name : "<null>");
            printf(" params=%d", node->data.function.param_count);
            if (node->data.function.is_inline) printf(" inline");
            break;
        case AST_IF_STMT:
            printf(" has_else=%s", node->data.if_stmt.else_branch ? "yes" : "no");
            break;
        case AST_FOR_STMT:
            printf(" has_init=%s has_cond=%s has_inc=%s",
                   node->data.for_stmt.init ? "yes" : "no",
                   node->data.for_stmt.condition ? "yes" : "no",
                   node->data.for_stmt.increment ? "yes" : "no");
            break;
        case AST_RETURN_STMT:
            printf(" has_expr=%s", node->data.return_stmt.expr ? "yes" : "no");
            break;
        case AST_GOTO_STMT:
            printf(" label='%s'", node->data.goto_stmt.label_name ? node->data.goto_stmt.label_name : "<null>");
            break;
        case AST_LABEL:
            printf(" name='%s'", node->data.label.label_name ? node->data.label.label_name : "<null>");
            break;
        case AST_FUNCTION_CALL:
            printf(" args=%d", node->data.call.arg_count);
            break;
        case AST_MEMBER_ACCESS:
        case AST_POINTER_ACCESS:
            printf(" member='%s'", node->data.member.member_name ? node->data.member.member_name : "<null>");
            break;
        case AST_CAST_EXPR:
            printf(" target_type=");
            if (node->data.cast.target_type) {
                char *ts = type_to_string(node->data.cast.target_type);
                printf("%s", ts);
                free(ts);
            } else {
                printf("<null>");
            }
            break;
        case AST_PRINTEL_CALL:
            printf(" format=\"%s\" args=%d", 
                   node->data.printel.format ? node->data.printel.format : "",
                   node->data.printel.arg_count);
            break;
        case AST_SCANEL_CALL:
            printf(" format=\"%s\" args=%d",
                   node->data.scanel.format ? node->data.scanel.format : "",
                   node->data.scanel.arg_count);
            break;
        case AST_TIMER_STMT:
            printf(" has_start=%s has_end=%s",
                   node->data.timer.start ? "yes" : "no",
                   node->data.timer.end ? "yes" : "no");
            break;
        case AST_STRUCT_DEF:
            printf(" name='%s' fields=%d",
                   node->data.struct_def.name ? node->data.struct_def.name : "<null>",
                   node->data.struct_def.member_count);
            break;
        case AST_UNION_DEF:
            printf(" name='%s' fields=%d",
                   node->data.struct_def.name ? node->data.struct_def.name : "<null>",
                   node->data.struct_def.member_count);
            break;
        case AST_TYPEDEF:
            printf(" alias='%s'", node->data.identifier.name ? node->data.identifier.name : "<null>");
            break;
        case AST_INCLUDE:
            printf(" header='%s' system=%s",
                   node->data.include.header_name ? node->data.include.header_name : "",
                   node->data.include.is_system ? "yes" : "no");
            break;
        case AST_DEFINE:
            printf(" macro='%s'", node->data.define.macro_name ? node->data.define.macro_name : "<null>");
            break;
        case AST_IFDEF:
        case AST_IFNDEF:
            printf(" macro='%s'", node->data.define.macro_name ? node->data.define.macro_name : "<null>");
            break;
        case AST_BLOCK:
            printf(" stmts=%d", node->data.block.stmt_count);
            break;
        case AST_PROGRAM:
            printf(" decls=%d", node->data.program.decl_count);
            break;
        default:
            break;
    }
    if (node->jpp_type) {
        char *ts = type_to_string(node->jpp_type);
        printf(" type=%s", ts);
        free(ts);
    }
    printf("]\n");
}

void ast_print(AstNode *node, int indent) {
    if (!node) return;
    ast_print_node_details(node, indent);
    for (int i = 0; i < node->child_count; i++) {
        ast_print(node->children[i], indent + 1);
    }
}

void ast_print_summary(AstNode *node) {
    if (!node) return;
    printf("\n=== AST SUMMARY ===\n");
    printf("Root: %s\n", ast_node_name(node->type));
    int total_nodes = 0;
    int max_depth = 0;
    typedef struct { AstNode *node; int depth; } StackItem;
    StackItem *stack = malloc(1024 * sizeof(StackItem));
    int stack_size = 0;
    stack[stack_size++] = (StackItem){node, 0};
    while (stack_size > 0) {
        StackItem item = stack[--stack_size];
        total_nodes++;
        if (item.depth > max_depth) max_depth = item.depth;
        for (int i = item.node->child_count - 1; i >= 0; i--) {
            if (item.node->children[i]) {
                stack[stack_size++] = (StackItem){item.node->children[i], item.depth + 1};
            }
        }
    }
    free(stack);
    printf("Total nodes: %d\n", total_nodes);
    printf("Max depth: %d\n", max_depth);
    printf("===================\n\n");
}

static void ast_free_node_data(AstNode *node) {
    if (!node) return;
    switch (node->type) {
        case AST_IDENTIFIER:
            free(node->data.identifier.name);
            break;
        case AST_STRING_LITERAL:
            free(node->data.string_literal.str_val);
            break;
        case AST_BINARY_EXPR:
            free(node->data.binary.op);
            break;
        case AST_UNARY_EXPR:
            free(node->data.unary.op);
            break;
        case AST_VAR_DECL:
        case AST_POINTER_DECL:
        case AST_ARRAY_DECL:
            free(node->data.var_decl.var_name);
            break;
        case AST_FUNCTION_DEF:
        case AST_FUNCTION_DECL:
            free(node->data.function.func_name);
            free(node->data.function.params);
            break;
        case AST_BLOCK:
            free(node->data.block.stmts);
            break;
        case AST_GOTO_STMT:
            free(node->data.goto_stmt.label_name);
            break;
        case AST_LABEL:
            free(node->data.label.label_name);
            break;
        case AST_MEMBER_ACCESS:
        case AST_POINTER_ACCESS:
            free(node->data.member.member_name);
            break;
        case AST_FUNCTION_CALL:
            free(node->data.call.args);
            break;
        case AST_PRINTEL_CALL:
            free(node->data.printel.format);
            free(node->data.printel.args);
            break;
        case AST_SCANEL_CALL:
            free(node->data.scanel.format);
            free(node->data.scanel.args);
            break;
        case AST_STRUCT_DEF:
        case AST_UNION_DEF:
            free(node->data.struct_def.name);
            free(node->data.struct_def.members);
            break;
        case AST_TYPEDEF:
            free(node->data.identifier.name);
            break;
        case AST_INCLUDE:
            free(node->data.include.header_name);
            break;
        case AST_DEFINE:
            free(node->data.define.macro_name);
            free(node->data.define.replacement);
            break;
        case AST_IFDEF:
        case AST_IFNDEF:
            free(node->data.define.macro_name);
            break;
        case AST_PROGRAM:
            free(node->data.program.declarations);
            break;
        case AST_SWITCH_STMT:
            free(node->data.switch_stmt.cases);
            break;
        case AST_ENUM_DEF:
            free(node->data.struct_def.name);
            break;
        default:
            break;
    }
    if (node->jpp_type) {
        bool is_builtin = false;
        JppType *builtins[] = {
            jpp_type_void, jpp_type_bool, jpp_type_char, jpp_type_short,
            jpp_type_int, jpp_type_long, jpp_type_long_long,
            jpp_type_uchar, jpp_type_ushort, jpp_type_uint,
            jpp_type_ulong, jpp_type_ulong_long,
            jpp_type_float, jpp_type_double, jpp_type_long_double,
            jpp_type_very_long_double, jpp_type_string
        };
        int num_builtins = sizeof(builtins) / sizeof(builtins[0]);
        for (int i = 0; i < num_builtins; i++) {
            if (node->jpp_type == builtins[i]) {
                is_builtin = true;
                break;
            }
        }
        if (!is_builtin) {
            type_free(node->jpp_type);
        }
    }
    free(node->filename);
    free(node->children);
}

void ast_free(AstNode *node) {
    if (!node) return;
    for (int i = 0; i < node->child_count; i++) {
        ast_free(node->children[i]);
    }
    ast_free_node_data(node);
    free(node);
}

AstNode *ast_clone(AstNode *node) {
    if (!node) return NULL;
    AstNode *clone = ast_new_node(node->type);
    clone->line = node->line;
    clone->column = node->column;
    if (node->filename) clone->filename = strdup(node->filename);
    if (node->jpp_type) {
        clone->jpp_type = node->jpp_type;
    }
    switch (node->type) {
        case AST_INT_LITERAL:
            clone->data.int_literal.int_val = node->data.int_literal.int_val;
            break;
        case AST_FLOAT_LITERAL:
            clone->data.float_literal.float_val = node->data.float_literal.float_val;
            break;
        case AST_STRING_LITERAL:
            clone->data.string_literal.str_val = strdup(node->data.string_literal.str_val);
            break;
        case AST_CHAR_LITERAL:
            clone->data.char_literal.char_val = node->data.char_literal.char_val;
            break;
        case AST_BOOL_LITERAL:
            clone->data.bool_literal.bool_val = node->data.bool_literal.bool_val;
            break;
        case AST_IDENTIFIER:
            clone->data.identifier.name = strdup(node->data.identifier.name);
            clone->data.identifier.symbol = node->data.identifier.symbol;
            break;
        case AST_BINARY_EXPR:
            clone->data.binary.op = strdup(node->data.binary.op);
            clone->data.binary.left = ast_clone(node->data.binary.left);
            clone->data.binary.right = ast_clone(node->data.binary.right);
            break;
        case AST_UNARY_EXPR:
            clone->data.unary.op = strdup(node->data.unary.op);
            clone->data.unary.operand = ast_clone(node->data.unary.operand);
            break;
        case AST_TERNARY_EXPR:
            clone->data.ternary.cond = ast_clone(node->data.ternary.cond);
            clone->data.ternary.true_expr = ast_clone(node->data.ternary.true_expr);
            clone->data.ternary.false_expr = ast_clone(node->data.ternary.false_expr);
            break;
        case AST_VAR_DECL:
        case AST_POINTER_DECL:
            clone->data.var_decl.var_type = node->data.var_decl.var_type;
            clone->data.var_decl.var_name = strdup(node->data.var_decl.var_name);
            clone->data.var_decl.init_expr = ast_clone(node->data.var_decl.init_expr);
            clone->data.var_decl.is_const = node->data.var_decl.is_const;
            clone->data.var_decl.is_static = node->data.var_decl.is_static;
            clone->data.var_decl.is_extern = node->data.var_decl.is_extern;
            break;
        case AST_FUNCTION_DEF:
            clone->data.function.return_type = node->data.function.return_type;
            clone->data.function.func_name = strdup(node->data.function.func_name);
            clone->data.function.param_count = node->data.function.param_count;
            clone->data.function.is_inline = node->data.function.is_inline;
            if (node->data.function.param_count > 0) {
                clone->data.function.params = malloc(node->data.function.param_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.function.param_count; i++) {
                    clone->data.function.params[i] = ast_clone(node->data.function.params[i]);
                }
            }
            clone->data.function.body = ast_clone(node->data.function.body);
            break;
        case AST_BLOCK:
            clone->data.block.stmt_count = node->data.block.stmt_count;
            if (node->data.block.stmt_count > 0) {
                clone->data.block.stmts = malloc(node->data.block.stmt_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.block.stmt_count; i++) {
                    clone->data.block.stmts[i] = ast_clone(node->data.block.stmts[i]);
                }
            }
            break;
        case AST_IF_STMT:
            clone->data.if_stmt.condition = ast_clone(node->data.if_stmt.condition);
            clone->data.if_stmt.then_branch = ast_clone(node->data.if_stmt.then_branch);
            clone->data.if_stmt.else_branch = ast_clone(node->data.if_stmt.else_branch);
            break;
        case AST_FOR_STMT:
            clone->data.for_stmt.init = ast_clone(node->data.for_stmt.init);
            clone->data.for_stmt.condition = ast_clone(node->data.for_stmt.condition);
            clone->data.for_stmt.increment = ast_clone(node->data.for_stmt.increment);
            clone->data.for_stmt.body = ast_clone(node->data.for_stmt.body);
            break;
        case AST_WHILE_STMT:
            clone->data.while_stmt.condition = ast_clone(node->data.while_stmt.condition);
            clone->data.while_stmt.body = ast_clone(node->data.while_stmt.body);
            break;
        case AST_DO_WHILE_STMT:
            clone->data.do_while.body = ast_clone(node->data.do_while.body);
            clone->data.do_while.condition = ast_clone(node->data.do_while.condition);
            break;
        case AST_RETURN_STMT:
            clone->data.return_stmt.expr = ast_clone(node->data.return_stmt.expr);
            break;
        case AST_GOTO_STMT:
            clone->data.goto_stmt.label_name = strdup(node->data.goto_stmt.label_name);
            break;
        case AST_LABEL:
            clone->data.label.label_name = strdup(node->data.label.label_name);
            clone->data.label.stmt = ast_clone(node->data.label.stmt);
            break;
        case AST_FUNCTION_CALL:
            clone->data.call.func = ast_clone(node->data.call.func);
            clone->data.call.arg_count = node->data.call.arg_count;
            if (node->data.call.arg_count > 0) {
                clone->data.call.args = malloc(node->data.call.arg_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.call.arg_count; i++) {
                    clone->data.call.args[i] = ast_clone(node->data.call.args[i]);
                }
            }
            break;
        case AST_ARRAY_ACCESS:
            clone->data.array_access.array = ast_clone(node->data.array_access.array);
            clone->data.array_access.index = ast_clone(node->data.array_access.index);
            break;
        case AST_MEMBER_ACCESS:
        case AST_POINTER_ACCESS:
            clone->data.member.object = ast_clone(node->data.member.object);
            clone->data.member.member_name = strdup(node->data.member.member_name);
            break;
        case AST_CAST_EXPR:
            clone->data.cast.target_type = node->data.cast.target_type;
            clone->data.cast.expr = ast_clone(node->data.cast.expr);
            break;
        case AST_PRINTEL_CALL:
            clone->data.printel.format = strdup(node->data.printel.format);
            clone->data.printel.arg_count = node->data.printel.arg_count;
            if (node->data.printel.arg_count > 0) {
                clone->data.printel.args = malloc(node->data.printel.arg_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.printel.arg_count; i++) {
                    clone->data.printel.args[i] = ast_clone(node->data.printel.args[i]);
                }
            }
            break;
        case AST_SCANEL_CALL:
            clone->data.scanel.format = strdup(node->data.scanel.format);
            clone->data.scanel.arg_count = node->data.scanel.arg_count;
            if (node->data.scanel.arg_count > 0) {
                clone->data.scanel.args = malloc(node->data.scanel.arg_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.scanel.arg_count; i++) {
                    clone->data.scanel.args[i] = ast_clone(node->data.scanel.args[i]);
                }
            }
            break;
        case AST_TIMER_STMT:
            clone->data.timer.start = ast_clone(node->data.timer.start);
            clone->data.timer.end = ast_clone(node->data.timer.end);
            clone->data.timer.body = ast_clone(node->data.timer.body);
            break;
        case AST_STRUCT_DEF:
        case AST_UNION_DEF:
            clone->data.struct_def.name = strdup(node->data.struct_def.name);
            clone->data.struct_def.member_count = node->data.struct_def.member_count;
            if (node->data.struct_def.member_count > 0) {
                clone->data.struct_def.members = malloc(node->data.struct_def.member_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.struct_def.member_count; i++) {
                    clone->data.struct_def.members[i] = ast_clone(node->data.struct_def.members[i]);
                }
            }
            break;
        case AST_TYPEDEF:
            clone->data.identifier.name = strdup(node->data.identifier.name);
            clone->data.type_name.type = node->data.type_name.type;
            break;
        case AST_INCLUDE:
            clone->data.include.header_name = strdup(node->data.include.header_name);
            clone->data.include.is_system = node->data.include.is_system;
            break;
        case AST_DEFINE:
            clone->data.define.macro_name = strdup(node->data.define.macro_name);
            clone->data.define.replacement = strdup(node->data.define.replacement);
            break;
        case AST_IFDEF:
        case AST_IFNDEF:
            clone->data.define.macro_name = strdup(node->data.define.macro_name);
            break;
        case AST_PROGRAM:
            clone->data.program.decl_count = node->data.program.decl_count;
            if (node->data.program.decl_count > 0) {
                clone->data.program.declarations = malloc(node->data.program.decl_count * sizeof(AstNode *));
                for (int i = 0; i < node->data.program.decl_count; i++) {
                    clone->data.program.declarations[i] = ast_clone(node->data.program.declarations[i]);
                }
            }
            break;
        default:
            break;
    }
    switch (node->type) {
        case AST_BINARY_EXPR:
            if (clone->data.binary.left) ast_add_child(clone, clone->data.binary.left);
            if (clone->data.binary.right) ast_add_child(clone, clone->data.binary.right);
            break;
        case AST_UNARY_EXPR:
            if (clone->data.unary.operand) ast_add_child(clone, clone->data.unary.operand);
            break;
        case AST_TERNARY_EXPR:
            if (clone->data.ternary.cond) ast_add_child(clone, clone->data.ternary.cond);
            if (clone->data.ternary.true_expr) ast_add_child(clone, clone->data.ternary.true_expr);
            if (clone->data.ternary.false_expr) ast_add_child(clone, clone->data.ternary.false_expr);
            break;
        case AST_VAR_DECL:
        case AST_POINTER_DECL:
            if (clone->data.var_decl.init_expr) ast_add_child(clone, clone->data.var_decl.init_expr);
            break;
        case AST_FUNCTION_DEF:
            for (int i = 0; i < clone->data.function.param_count; i++) {
                if (clone->data.function.params[i]) ast_add_child(clone, clone->data.function.params[i]);
            }
            if (clone->data.function.body) ast_add_child(clone, clone->data.function.body);
            break;
        case AST_BLOCK:
            for (int i = 0; i < clone->data.block.stmt_count; i++) {
                if (clone->data.block.stmts[i]) ast_add_child(clone, clone->data.block.stmts[i]);
            }
            break;
        case AST_IF_STMT:
            if (clone->data.if_stmt.condition) ast_add_child(clone, clone->data.if_stmt.condition);
            if (clone->data.if_stmt.then_branch) ast_add_child(clone, clone->data.if_stmt.then_branch);
            if (clone->data.if_stmt.else_branch) ast_add_child(clone, clone->data.if_stmt.else_branch);
            break;
        case AST_FOR_STMT:
            if (clone->data.for_stmt.init) ast_add_child(clone, clone->data.for_stmt.init);
            if (clone->data.for_stmt.condition) ast_add_child(clone, clone->data.for_stmt.condition);
            if (clone->data.for_stmt.increment) ast_add_child(clone, clone->data.for_stmt.increment);
            if (clone->data.for_stmt.body) ast_add_child(clone, clone->data.for_stmt.body);
            break;
        case AST_WHILE_STMT:
            if (clone->data.while_stmt.condition) ast_add_child(clone, clone->data.while_stmt.condition);
            if (clone->data.while_stmt.body) ast_add_child(clone, clone->data.while_stmt.body);
            break;
        case AST_DO_WHILE_STMT:
            if (clone->data.do_while.body) ast_add_child(clone, clone->data.do_while.body);
            if (clone->data.do_while.condition) ast_add_child(clone, clone->data.do_while.condition);
            break;
        case AST_RETURN_STMT:
            if (clone->data.return_stmt.expr) ast_add_child(clone, clone->data.return_stmt.expr);
            break;
        case AST_LABEL:
            if (clone->data.label.stmt) ast_add_child(clone, clone->data.label.stmt);
            break;
        case AST_FUNCTION_CALL:
            if (clone->data.call.func) ast_add_child(clone, clone->data.call.func);
            for (int i = 0; i < clone->data.call.arg_count; i++) {
                if (clone->data.call.args[i]) ast_add_child(clone, clone->data.call.args[i]);
            }
            break;
        case AST_ARRAY_ACCESS:
            if (clone->data.array_access.array) ast_add_child(clone, clone->data.array_access.array);
            if (clone->data.array_access.index) ast_add_child(clone, clone->data.array_access.index);
            break;
        case AST_MEMBER_ACCESS:
        case AST_POINTER_ACCESS:
            if (clone->data.member.object) ast_add_child(clone, clone->data.member.object);
            break;
        case AST_CAST_EXPR:
            if (clone->data.cast.expr) ast_add_child(clone, clone->data.cast.expr);
            break;
        case AST_PRINTEL_CALL:
            for (int i = 0; i < clone->data.printel.arg_count; i++) {
                if (clone->data.printel.args[i]) ast_add_child(clone, clone->data.printel.args[i]);
            }
            break;
        case AST_SCANEL_CALL:
            for (int i = 0; i < clone->data.scanel.arg_count; i++) {
                if (clone->data.scanel.args[i]) ast_add_child(clone, clone->data.scanel.args[i]);
            }
            break;
        case AST_TIMER_STMT:
            if (clone->data.timer.start) ast_add_child(clone, clone->data.timer.start);
            if (clone->data.timer.end) ast_add_child(clone, clone->data.timer.end);
            if (clone->data.timer.body) ast_add_child(clone, clone->data.timer.body);
            break;
        case AST_STRUCT_DEF:
        case AST_UNION_DEF:
            for (int i = 0; i < clone->data.struct_def.member_count; i++) {
                if (clone->data.struct_def.members[i]) ast_add_child(clone, clone->data.struct_def.members[i]);
            }
            break;
        case AST_PROGRAM:
            for (int i = 0; i < clone->data.program.decl_count; i++) {
                if (clone->data.program.declarations[i]) ast_add_child(clone, clone->data.program.declarations[i]);
            }
            break;
        default:
            break;
    }
    return clone;
}

}
