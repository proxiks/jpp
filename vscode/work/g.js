// Tree-sitter grammar for J++ Programming Language
// Author: Jatin (linuxab)

module.exports = grammar({
  name: 'jpp',

  extras: $ => [
    /\\s/,
    $.comment,
  ],

  word: $ => $.identifier,

  rules: {
    source_file: $ => repeat($.declaration),

    declaration: $ => choice(
      $.function_definition,
      $.variable_declaration,
      $.preprocessor_directive,
      $.struct_declaration,
      $.inline_assembly,
      $.timer_statement,
    ),

    // Preprocessor
    preprocessor_directive: $ => choice(
      seq('#include', choice(
        seq('<', $.header_name, '>'),
        seq('"', $.header_name, '"')
      )),
      seq('#define', $.identifier, optional($.preprocessor_value)),
      seq('#undef', $.identifier),
      seq('#indef', $.identifier),     // J++ specific
      seq('#ifndef', $.identifier),
      seq('#ifdef', $.identifier),
      seq('#if', $.expression),
      seq('#error', $.string_literal),
      seq('#pragma', $.identifier),
      seq('#line', $.number),
    ),

    header_name: $ => /[a-zA-Z0-9_+\\-.]+/,
    preprocessor_value: $ => /.*/,

    // Functions
    function_definition: $ => seq(
      optional($.attribute),
      optional($.type_qualifier),
      $.type,
      $.identifier,
      '(',
      optional($.parameter_list),
      ')',
      $.compound_statement,
    ),

    attribute: $ => choice(
      'boot',
      'kernel',
      'aie_kernel',
      'shim_kernel',
    ),

    type_qualifier: $ => choice(
      'const',
      'static',
      'extern',
      'inline',
      'xdna_l1',
      'xdna_l2',
      'xdna_l3',
      'dma_buffer',
      'tile_coord',
    ),

    type: $ => choice(
      'void',
      'bool',
      'char',
      'short',
      'int',
      'long',
      'float',
      'double',
      'unsigned',
      'signed',
      'string',
      'ptr',
      'auto',
      'register',
      'uint8',
      'uint16',
      'uint32',
      'uint64',
      'int8',
      'int16',
      'int32',
      'int64',
      'bfloat16',
      'float32',
      'float64',
      'phys_addr',
      'virt_addr',
      'size_t',
      'ssize_t',
      'off_t',
      'pid_t',
      'tid_t',
      'FILE',
      'dma_desc',
      'xdna_dma',
      'xdna_stream_route',
      'tile_coord',
      'xdna_counter',
      seq('very', 'long', 'double'),
      seq('short', 'inf'),
      seq('long', 'double'),
    ),

    parameter_list: $ => seq(
      $.parameter,
      repeat(seq(',', $.parameter)),
    ),

    parameter: $ => seq(
      optional($.type_qualifier),
      $.type,
      optional(seq('*', repeat('*'))),
      $.identifier,
    ),

    // Statements
    compound_statement: $ => seq(
      '{',
      repeat($.statement),
      '}',
    ),

    statement: $ => choice(
      $.expression_statement,
      $.variable_declaration,
      $.if_statement,
      $.for_statement,
      $.while_statement,
      $.do_while_statement,
      $.goto_statement,
      $.return_statement,
      $.compound_statement,
      $.inline_assembly,
      $.timer_statement,
      $.break_statement,
      $.continue_statement,
      $.switch_statement,
    ),

    expression_statement: $ => seq($.expression, ';'),

    variable_declaration: $ => seq(
      optional($.type_qualifier),
      $.type,
      repeat('*'),
      $.identifier,
      optional(seq('=', $.initializer)),
      repeat(seq(',', $.identifier, optional(seq('=', $.initializer)))),
      ';',
    ),

    initializer: $ => choice(
      $.expression,
      $.array_initializer,
    ),

    array_initializer: $ => seq(
      '{',
      optional(seq($.expression, repeat(seq(',', $.expression)))),
      '}',
    ),

    if_statement: $ => seq(
      'if',
      '(',
      $.expression,
      ')',
      $.statement,
      optional(seq('else', $.statement)),
    ),

    for_statement: $ => choice(
      // Shorthand: for(int i = 0 < 10)
      seq(
        'for',
        '(',
        $.type,
        $.identifier,
        '=',
        $.expression,
        '<',
        $.expression,
        ')',
        $.statement,
      ),
      // Full C-style: for(int i = 0; i < 10; i++)
      seq(
        'for',
        '(',
        optional(seq($.type, $.identifier, '=', $.expression, ';')),
        optional(seq($.expression, ';')),
        optional($.expression),
        ')',
        $.statement,
      ),
    ),

    while_statement: $ => seq(
      'while',
      '(',
      $.expression,
      ')',
      $.statement,
    ),

    do_while_statement: $ => seq(
      'do',
      $.statement,
      'while',
      '(',
      $.expression,
      ')',
      ';',
    ),

    goto_statement: $ => seq(
      'goto',
      $.identifier,
      choice(':', ';'),
    ),

    return_statement: $ => seq(
      'return',
      optional($.expression),
      ':',
    ),

    break_statement: $ => seq('break', ';'),
    continue_statement: $ => seq('continue', ';'),

    switch_statement: $ => seq(
      'switch',
      '(',
      $.expression,
      ')',
      '{',
      repeat($.case_statement),
      '}',
    ),

    case_statement: $ => choice(
      seq('case', $.expression, ':', repeat($.statement)),
      seq('default', ':', repeat($.statement)),
    ),

    timer_statement: $ => seq(
      'timer',
      '(',
      $.expression,
      '<',
      $.expression,
      ')',
      '{',
      repeat($.timer_clause),
      '}',
    ),

    timer_clause: $ => choice(
      seq('=(', $.identifier, ')'),
      seq('(.', $.identifier, ')'),
    ),

    // Inline Assembly
    inline_assembly: $ => seq(
      'asm',
      optional('volatile'),
      '(',
      $.string_literal,
      optional(seq(
        ':',
        optional($.asm_operand_list),
        repeat(seq(
          ':',
          optional($.asm_operand_list),
        )),
      )),
      ');',
    ),

    asm_operand_list: $ => seq(
      $.asm_operand,
      repeat(seq(',', $.asm_operand)),
    ),

    asm_operand: $ => seq(
      '"',
      /[^"]*/,
      '"',
      '(',
      $.expression,
      ')',
    ),

    // Structs
    struct_declaration: $ => seq(
      optional('const'),
      'struct',
      '(',
      $.identifier,
      ')',
      '{',
      repeat($.variable_declaration),
      '}',
    ),

    // Expressions
    expression: $ => choice(
      $.assignment_expression,
      $.binary_expression,
      $.unary_expression,
      $.postfix_expression,
      $.primary_expression,
      $.cast_expression,
      $.conditional_expression,
    ),

    assignment_expression: $ => seq(
      $.unary_expression,
      choice('=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>='),
      $.expression,
    ),

    binary_expression: $ => prec.left(choice(
      seq($.expression, '||', $.expression),
      seq($.expression, '&&', $.expression),
      seq($.expression, '|', $.expression),
      seq($.expression, '^', $.expression),
      seq($.expression, '&', $.expression),
      seq($.expression, '==', $.expression),
      seq($.expression, '!=', $.expression),
      seq($.expression, '<', $.expression),
      seq($.expression, '>', $.expression),
      seq($.expression, '<=', $.expression),
      seq($.expression, '>=', $.expression),
      seq($.expression, '<<', $.expression),
      seq($.expression, '>>', $.expression),
      seq($.expression, '+', $.expression),
      seq($.expression, '-', $.expression),
      seq($.expression, '*', $.expression),
      seq($.expression, '/', $.expression),
      seq($.expression, '%', $.expression),
    )),

    unary_expression: $ => choice(
      seq(choice('++', '--', '+', '-', '!', '~', '*', '&'), $.unary_expression),
      $.postfix_expression,
      seq('sizeof', '(', $.type, ')'),
      seq('typeof', '(', $.expression, ')'),
      seq('offsetof', '(', $.identifier, ',', $.identifier, ')'),
    ),

    postfix_expression: $ => prec.left(choice(
      seq($.primary_expression, '++'),
      seq($.primary_expression, '--'),
      seq($.primary_expression, '(', optional($.argument_list), ')'),
      seq($.primary_expression, '[', $.expression, ']'),
      seq($.primary_expression, '.', $.identifier),
      seq($.primary_expression, '->', $.identifier),
    )),

    primary_expression: $ => choice(
      $.identifier,
      $.number,
      $.string_literal,
      $.char_literal,
      'true',
      'false',
      'NUL',
      'NULL',
      seq('(', $.expression, ')'),
    ),

    cast_expression: $ => seq(
      '(',
      $.type,
      ')',
      $.unary_expression,
    ),

    conditional_expression: $ => seq(
      $.expression,
      '?',
      $.expression,
      ':',
      $.expression,
    ),

    argument_list: $ => seq(
      $.expression,
      repeat(seq(',', $.expression)),
    ),

    // Literals
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    number: $ => choice(
      /0[xX][0-9a-fA-F]+/,     // Hex
      /0[bB][01]+/,            // Binary
      /0[oO][0-7]+/,           // Octal
      /[0-9]+\\.?[0-9]*([eE][+-]?[0-9]+)?/, // Decimal/Float
    ),

    string_literal: $ => choice(
      seq("'", repeat(choice(/[^'\\\\]/, /\\\\./)), "'"),
      seq('"', repeat(choice(/[^"\\\\]/, /\\\\./)), '"'),
    ),

    char_literal: $ => seq(
      "'",
      choice(/[^'\\\\]/, /\\\\./),
      "'",
    ),

    comment: $ => choice(
      seq('//', /.*/),
      seq('/*', /[^*]*\\*+([^/*][^*]*\\*+)*/, '/'),
    ),
  }
});