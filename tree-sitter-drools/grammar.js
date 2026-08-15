/// <reference types="tree-sitter-cli/dsl" />
// tree-sitter-drools/grammar.js
// Tree-sitter grammar for Drools Rule Language (.drl, .dsl)
// Generated from official Apache KIE Drools ANTLR4 DRL parser specifications (DRLParser.g4)

module.exports = grammar({
  name: 'drools',

  extras: $ => [
    $.line_comment,
    $.block_comment,
    /\s+/,
  ],

  word: $ => $.identifier,

  rules: {
    compilation_unit: $ => seq(
      optional($.package_statement),
      repeat($.unit_statement),
      repeat($.import_statement),
      repeat($.global_declaration),
      repeat($.declare_statement),
      repeat($.function_declaration),
      repeat($.query_declaration),
      repeat($.rule_declaration),
    ),

    package_statement: $ => seq(
      'package',
      field('name', $.scoped_identifier),
      optional(';'),
    ),

    unit_statement: $ => seq(
      'unit',
      field('name', $.scoped_identifier),
      optional(';'),
    ),

    import_statement: $ => seq(
      'import',
      optional(choice('static', 'function')),
      field('name', $.scoped_identifier),
      optional(seq('.', '*')),
      optional(';'),
    ),

    global_declaration: $ => seq(
      'global',
      field('type', $.type_identifier),
      field('name', $.identifier),
      optional(';'),
    ),

    declare_statement: $ => seq(
      'declare',
      optional('trait'),
      field('name', $.type_identifier),
      optional(seq('extends', $.scoped_identifier)),
      repeat(choice($.field_declaration, $.annotation)),
      'end',
    ),

    field_declaration: $ => seq(
      repeat($.annotation),
      field('name', $.identifier),
      ':',
      field('type', $.type_identifier),
      optional(seq('=', $.expression)),
      optional(';'),
    ),

    function_declaration: $ => seq(
      'function',
      optional(field('return_type', $.type_identifier)),
      field('name', $.identifier),
      '(',
      optional($.parameter_list),
      ')',
      field('body', $.block),
    ),

    query_declaration: $ => seq(
      'query',
      field('name', $.string),
      optional(seq('(', optional($.parameter_list), ')')),
      repeat($.lhs_pattern),
      'end',
    ),

    rule_declaration: $ => seq(
      'rule',
      field('name', $.string),
      optional(seq('extends', $.string)),
      repeat($.attribute),
      'when',
      repeat($.lhs_pattern),
      'then',
      optional(field('rhs', $.rhs_block)),
      'end',
    ),

    attribute: $ => seq(
      field('name', choice(
        'salience',
        'agenda-group',
        'ruleflow-group',
        'activation-group',
        'lock-on-active',
        'no-loop',
        'auto-focus',
        'enabled',
        'dialect',
        'duration',
        'timer',
        'calendars',
        'date-effective',
        'date-expires',
        'refract',
        'direct',
      )),
      field('value', choice(
        $.number,
        $.string,
        $.boolean,
        $.identifier,
        $.expression,
      )),
    ),

    lhs_pattern: $ => choice(
      $.conditional_element,
      $.pattern_binding,
      $.fact_pattern,
      $.accumulate_clause,
      $.eval_clause,
    ),

    conditional_element: $ => seq(
      field('kind', choice('and', 'or', 'not', 'exists', 'forall')),
      optional(seq('(', repeat($.lhs_pattern), ')')),
    ),

    pattern_binding: $ => seq(
      $.variable_binding,
      choice($.fact_pattern, $.accumulate_clause),
    ),

    variable_binding: $ => seq(
      field('name', $.bound_variable),
      ':',
    ),

    fact_pattern: $ => seq(
      field('type', $.type_identifier),
      '(',
      optional(commaSep1($.constraint)),
      ')',
      optional($.over_clause),
      optional($.from_clause),
    ),

    over_clause: $ => seq(
      'over',
      field('window', seq(
        'window:',
        choice('time', 'length'),
        '(',
        $.expression,
        ')',
      )),
    ),

    from_clause: $ => seq(
      'from',
      choice(
        seq('entry-point', $.string),
        $.expression,
      ),
    ),

    constraint: $ => choice(
      $.field_constraint,
      $.positional_constraint,
      $.expression,
    ),

    field_constraint: $ => seq(
      field('field', $.identifier),
      field('operator', $.operator),
      field('value', $.expression),
    ),

    positional_constraint: $ => seq(
      field('index', $.number),
      ':',
      $.expression,
    ),

    operator: $ => choice(
      '==', '!=', '>', '>=', '<', '<=',
      'matches', seq('not', 'matches'),
      'contains', seq('not', 'contains'),
      'memberOf', seq('not', 'memberOf'),
      'soundslike',
      'in', seq('not', 'in'),
      'excludes',
      'after', 'before', 'coincides', 'during', 'finishes', 'finishedby',
      'meets', 'metby', 'overlaps', 'overlappedby', 'starts', 'startedby',
    ),

    accumulate_clause: $ => seq(
      'accumulate',
      '(',
      $.lhs_pattern,
      ';',
      choice(
        commaSep1($.accumulate_function),
        $.accumulate_custom_block,
      ),
      ')',
    ),

    accumulate_function: $ => seq(
      optional(seq($.variable_binding)),
      field('name', choice('sum', 'avg', 'min', 'max', 'count', 'collectList', 'collectSet', 'collectArray', $.identifier)),
      '(',
      optional($.expression),
      ')',
    ),

    accumulate_custom_block: $ => seq(
      'init', '(', repeat($.expression), ')', ',',
      'action', '(', repeat($.expression), ')', ',',
      optional(seq('reverse', '(', repeat($.expression), ')', ',')),
      'result', '(', $.expression, ')',
    ),

    eval_clause: $ => seq(
      'eval',
      '(',
      $.expression,
      ')',
    ),

    rhs_block: $ => repeat1(
      choice(
        $.rhs_statement,
        $.rhs_action,
      ),
    ),

    rhs_action: $ => seq(
      field('name', choice('insert', 'insertLogical', 'modify', 'update', 'retract', 'delete')),
      '(',
      optional($.expression),
      ')',
      optional($.block),
      optional(';'),
    ),

    rhs_statement: $ => choice(
      $.block,
      prec(1, seq($.expression, optional(';'))),
    ),

    annotation: $ => seq(
      '@',
      field('name', $.identifier),
      optional(seq('(', optional($.expression), ')')),
    ),

    parameter_list: $ => commaSep1($.parameter),

    parameter: $ => seq(
      field('type', $.type_identifier),
      field('name', $.identifier),
    ),

    block: $ => seq(
      '{',
      repeat(choice($.rhs_statement, $.expression)),
      '}',
    ),

    expression: $ => prec.left(choice(
      $.bound_variable,
      $.identifier,
      $.scoped_identifier,
      $.number,
      $.string,
      $.boolean,
      $.null_literal,
      $.member_access,
      $.call_expression,
      $.binary_expression,
      $.parenthesized_expression,
    )),

    member_access: $ => prec(2, seq(
      $.expression,
      '.',
      $.identifier,
    )),

    call_expression: $ => prec(3, seq(
      $.expression,
      '(',
      optional(commaSep1($.expression)),
      ')',
    )),

    binary_expression: $ => prec.left(1, seq(
      $.expression,
      choice('+', '-', '*', '/', '%', '&&', '||', '==', '!=', '<', '<=', '>', '>='),
      $.expression,
    )),

    parenthesized_expression: $ => seq(
      '(',
      $.expression,
      ')',
    ),

    scoped_identifier: $ => prec.right(seq(
      $.identifier,
      repeat(seq('.', $.identifier)),
    )),

    type_identifier: $ => prec.right(seq(
      alias(/[A-Z][a-zA-Z0-9_]*/, $.identifier),
      repeat(seq('.', alias(/[A-Z][a-zA-Z0-9_]*/, $.identifier))),
    )),

    bound_variable: $ => /\$[a-zA-Z_][a-zA-Z0-9_]*/,

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    number: $ => /\d+(\.\d+)?([eE][+-]?\d+)?[fFdD]?|0x[0-9a-fA-F]+/,

    string: $ => choice(
      seq('"', repeat(choice(/[^"\\]/, /\\./)), '"'),
      seq("'", repeat(choice(/[^'\\]/, /\\./)), "'"),
    ),

    boolean: $ => choice('true', 'false'),

    null_literal: $ => 'null',

    line_comment: $ => token(seq('//', /.*/)),

    block_comment: $ => token(seq(
      '/*',
      /[^*]*\*+([^/*][^*]*\*+)*/,
      '/',
    )),
  },
});

function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}
