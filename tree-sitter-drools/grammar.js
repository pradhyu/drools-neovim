/// <reference types="tree-sitter-cli/dsl" />
// tree-sitter-drools/grammar.js
// Tree-sitter grammar for Drools Rule Language (.drl, .dsl)
// Aligned with official Apache KIE Drools ANTLR4 DRL parser specifications (DRLParser.g4)

module.exports = grammar({
  name: 'drools',

  extras: $ => [
    $.line_comment,
    $.hash_comment,
    $.block_comment,
    /\s+/,
  ],

  word: $ => $.identifier,

  rules: {
    compilation_unit: $ => repeat(choice(
      $.package_statement,
      $.unit_statement,
      $.import_statement,
      $.global_declaration,
      $.declare_statement,
      $.function_declaration,
      $.query_declaration,
      $.rule_declaration,
      $.annotation,
      ';',
    )),

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
      optional(choice('static', 'function', 'accumulate')),
      field('name', $.scoped_identifier),
      optional(choice(seq('.', '*'), $.identifier)),
      optional(';'),
    ),

    global_declaration: $ => seq(
      'global',
      field('type', $.type_spec),
      field('name', $.identifier),
      optional(';'),
    ),

    declare_statement: $ => choice(
      seq(
        'declare',
        'entry-point',
        field('name', choice($.string, $.identifier)),
        repeat($.annotation),
        'end',
        optional(';'),
      ),
      seq(
        'declare',
        'window',
        field('name', $.identifier),
        repeat($.annotation),
        repeat($.lhs_pattern),
        'end',
        optional(';'),
      ),
      seq(
        'declare',
        optional(choice('trait', 'enum')),
        field('name', $.scoped_identifier),
        optional(seq('extends', commaSep1($.scoped_identifier))),
        repeat(choice($.field_declaration, $.annotation, ';')),
        'end',
        optional(';'),
      ),
    ),

    field_declaration: $ => seq(
      repeat($.annotation),
      field('name', $.identifier),
      ':',
      field('type', $.type_spec),
      repeat($.annotation),
      optional(seq('=', $.expression)),
      repeat($.annotation),
      optional(';'),
    ),

    function_declaration: $ => seq(
      'function',
      repeat(choice('public', 'private', 'protected', 'static', 'final', 'synchronized')),
      optional(field('return_type', $.type_spec)),
      field('name', $.identifier),
      '(',
      optional($.parameter_list),
      ')',
      field('body', $.block),
    ),

    query_declaration: $ => seq(
      'query',
      field('name', choice($.string, $.identifier)),
      optional(seq('(', optional($.parameter_list), ')')),
      repeat($.lhs_pattern),
      'end',
      optional(';'),
    ),

    rule_declaration: $ => seq(
      'rule',
      field('name', $.string),
      repeat($.annotation),
      optional(seq('extends', $.string)),
      optional(seq('attributes', optional(':'))),
      repeat(choice($.attribute, $.annotation, ',', ';')),
      'when',
      optional(':'),
      repeat($.lhs_pattern),
      'then',
      optional(seq('[', $.identifier, ']')),
      optional(':'),
      optional(field('rhs', $.rhs_block)),
      'end',
      optional(';'),
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
      optional(':'),
      optional(field('value', choice(
        $.number,
        $.string,
        $.boolean,
        $.bound_variable,
        $.identifier,
        $.expression,
      ))),
    ),

    lhs_pattern: $ => choice(
      $.conditional_element,
      $.pattern_binding,
      $.fact_pattern,
      $.accumulate_clause,
      $.collect_clause,
      $.eval_clause,
    ),

    conditional_element: $ => seq(
      field('kind', choice('and', 'or', 'not', 'exists', 'forall')),
      optional(seq('(', repeat($.lhs_pattern), ')')),
    ),

    pattern_binding: $ => seq(
      $.variable_binding,
      choice($.fact_pattern, $.accumulate_clause, $.collect_clause),
    ),

    variable_binding: $ => seq(
      field('name', $.bound_variable),
      choice(':', ':='),
    ),

    fact_pattern: $ => seq(
      field('type', $.scoped_identifier),
      '(',
      optional(commaSep1($.constraint)),
      ')',
      optional($.over_clause),
      optional($.from_clause),
      optional(';'),
    ),

    over_clause: $ => seq(
      'over',
      field('window', choice(
        seq(
          'window:',
          choice('time', 'length'),
          '(',
          $.expression,
          ')',
        ),
        $.identifier,
      )),
    ),

    from_clause: $ => seq(
      'from',
      choice(
        seq('entry-point', choice($.string, $.identifier)),
        $.accumulate_clause,
        $.collect_clause,
        $.expression,
      ),
    ),

    collect_clause: $ => seq(
      'collect',
      '(',
      $.lhs_pattern,
      ')',
    ),

    constraint: $ => choice(
      $.field_constraint,
      $.positional_constraint,
      $.expression,
    ),

    field_constraint: $ => seq(
      optional($.variable_binding),
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
      '==', '!=', '>', '>=', '<', '<=', '~=',
      'matches', seq('not', 'matches'),
      'contains', seq('not', 'contains'),
      'memberOf', seq('not', 'memberOf'),
      'soundslike', seq('not', 'soundslike'),
      'in', seq('not', 'in'),
      'excludes', seq('not', 'excludes'),
      seq(
        optional('not'),
        choice(
          'after', 'before', 'coincides', 'during', 'finishes', 'finishedby',
          'meets', 'metby', 'overlaps', 'overlappedby', 'starts', 'startedby',
        ),
        optional(seq('[', $.expression, optional(seq(',', $.expression)), ']')),
      ),
    ),

    accumulate_clause: $ => seq(
      'accumulate',
      '(',
      $.lhs_pattern,
      choice(';', ','),
      choice(
        commaSep1($.accumulate_function),
        $.accumulate_custom_block,
      ),
      ')',
    ),

    accumulate_function: $ => seq(
      optional($.variable_binding),
      field('name', choice('sum', 'avg', 'average', 'min', 'max', 'count', 'collectList', 'collectSet', 'collectArray', $.identifier)),
      '(',
      optional($.expression),
      ')',
    ),

    accumulate_custom_block: $ => seq(
      'init', '(', repeat($.rhs_statement), ')', ',',
      'action', '(', repeat($.rhs_statement), ')', ',',
      optional(seq('reverse', '(', repeat($.rhs_statement), ')', ',')),
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
        $.rhs_action,
        $.rhs_statement,
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
      $.variable_declaration,
      $.return_statement,
      $.if_statement,
      $.for_statement,
      $.while_statement,
      $.try_statement,
      $.block,
      prec(1, seq($.expression, optional(choice(';', ',')))),
    ),

    variable_declaration: $ => prec(2, seq(
      optional('final'),
      field('type', $.type_spec),
      field('name', $.identifier),
      optional(seq('=', $.expression)),
      repeat(seq(',', $.identifier, optional(seq('=', $.expression)))),
      optional(';'),
    )),

    return_statement: $ => seq(
      'return',
      optional($.expression),
      optional(';'),
    ),

    if_statement: $ => prec.right(seq(
      'if',
      '(',
      $.expression,
      ')',
      $.rhs_statement,
      optional(seq('else', $.rhs_statement)),
    )),

    for_statement: $ => seq(
      'for',
      '(',
      choice(
        seq(optional($.rhs_statement), ';', optional($.expression), ';', optional($.expression)),
        seq(optional('final'), $.type_spec, $.identifier, ':', $.expression),
      ),
      ')',
      $.rhs_statement,
    ),

    while_statement: $ => seq(
      'while',
      '(',
      $.expression,
      ')',
      $.rhs_statement,
    ),

    try_statement: $ => seq(
      'try',
      $.block,
      repeat(seq('catch', '(', $.type_spec, $.identifier, ')', $.block)),
      optional(seq('finally', $.block)),
    ),

    annotation: $ => seq(
      '@',
      field('name', $.scoped_identifier),
      optional(seq('(', optional(commaSep1($.expression)), ')')),
    ),

    parameter_list: $ => commaSep1($.parameter),

    parameter: $ => seq(
      optional('final'),
      optional(field('type', $.type_spec)),
      optional('...'),
      field('name', choice($.identifier, $.bound_variable)),
    ),

    block: $ => seq(
      '{',
      repeat(choice($.rhs_action, $.rhs_statement)),
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
      $.new_expression,
      $.unary_expression,
      $.assignment_expression,
      $.member_access,
      $.array_access,
      $.call_expression,
      $.binary_expression,
      $.ternary_expression,
      $.parenthesized_expression,
    )),

    new_expression: $ => prec(4, seq(
      'new',
      $.type_spec,
      choice(
        seq('(', optional(commaSep1($.expression)), ')', optional($.block)),
        $.block,
      ),
    )),

    unary_expression: $ => prec(3, choice(
      seq(choice('!', '-', '+', '~', '++', '--'), $.expression),
      seq($.expression, choice('++', '--')),
    )),

    assignment_expression: $ => prec.right(1, seq(
      $.expression,
      choice('=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^='),
      $.expression,
    )),

    ternary_expression: $ => prec.right(1, seq(
      $.expression,
      '?',
      $.expression,
      ':',
      $.expression,
    )),

    member_access: $ => prec(2, seq(
      $.expression,
      choice('.', '?.', '!.', '::', '#'),
      $.identifier,
    )),

    array_access: $ => prec(3, seq(
      $.expression,
      '[',
      $.expression,
      ']',
    )),

    call_expression: $ => prec(3, seq(
      $.expression,
      '(',
      optional(commaSep1($.expression)),
      ')',
    )),

    binary_expression: $ => prec.left(1, seq(
      $.expression,
      choice('+', '-', '*', '/', '%', '&&', '||', '&', '|', '^', '==', '!=', '<', '<=', '>', '>=', '<<', '>>', '>>>', 'instanceof'),
      $.expression,
    )),

    parenthesized_expression: $ => seq(
      '(',
      $.expression,
      ')',
    ),

    type_spec: $ => prec.right(seq(
      $.scoped_identifier,
      optional($.type_arguments),
      repeat(seq('[', ']')),
    )),

    type_arguments: $ => seq(
      '<',
      commaSep1(choice(
        $.type_spec,
        seq('?', optional(seq(choice('extends', 'super'), $.type_spec))),
      )),
      '>',
    ),

    scoped_identifier: $ => prec.right(seq(
      $.identifier,
      repeat(seq('.', $.identifier)),
    )),

    type_identifier: $ => $.type_spec,

    bound_variable: $ => /\$[a-zA-Z_][a-zA-Z0-9_$]*/,

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_$]*/,

    number: $ => /\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d[\d_]*)?([fFdDlLbBiI]|ms|[dhms])?|0[xX][0-9a-fA-F_]+[lL]?|0[bB][01_]+[lL]?/,

    string: $ => choice(
      seq('"""', repeat(choice(/[^"\\]/, /\\./, /"[^"]/, /""[^"]/)), '"""'),
      seq('"', repeat(choice(/[^"\\]/, /\\./)), '"'),
      seq("'", repeat(choice(/[^'\\]/, /\\./)), "'"),
    ),

    boolean: $ => choice('true', 'false'),

    null_literal: $ => 'null',

    line_comment: $ => token(seq('//', /.*/)),

    hash_comment: $ => token(seq('#', /.*/)),

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
