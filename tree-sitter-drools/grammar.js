/// <reference types="tree-sitter-cli/dsl" />
// tree-sitter-drools/grammar.js
// Comprehensive Tree-sitter grammar for Drools Rule Language (.drl, .dsl)
// Supports Drools 6, 7, and 8 (Rule Units, OOPath, CEP Temporal Operators,
// Accumulate/Groupby, Declare Types/Traits/Enums/Windows/Entry-Points,
// Functions with Java bodies, Queries, and Java/MVEL RHS Consequence Blocks).

module.exports = grammar({
  name: 'drools',

  extras: $ => [
    $.line_comment,
    $.hash_comment,
    $.block_comment,
    /\s+/,
  ],

  word: $ => $.identifier,

  conflicts: $ => [
    [$.scoped_identifier, $.expression],
    [$.parameter, $.expression, $.scoped_identifier],
    [$.lhs_pattern, $.parameter],
    [$.block, $.array_initializer],
    [$.parameter, $.expression],
  ],

  rules: {
    compilation_unit: $ => repeat(choice(
      $.package_statement,
      $.unit_statement,
      $.import_statement,
      $.global_declaration,
      $.application_data_statement,
      $.expander_statement,
      $.attribute,
      $.declare_statement,
      $.function_declaration,
      $.query_declaration,
      $.rule_declaration,
      $.annotation,
    )),

    application_data_statement: $ => prec.right(seq(
      'application-data',
      field('type', $.type_spec),
      field('name', $.identifier),
      optional(';'),
    )),

    expander_statement: $ => prec.right(seq(
      optional('use'),
      'expander',
      choice($.scoped_identifier, $.identifier, /[^;\r\n]+/),
      optional(';'),
    )),

    package_statement: $ => prec.right(seq(
      'package',
      field('name', $.scoped_identifier),
      optional(';'),
    )),

    unit_statement: $ => prec.right(seq(
      'unit',
      field('name', $.scoped_identifier),
      optional(';'),
    )),

    import_statement: $ => prec.right(seq(
      'import',
      optional(choice('static', 'function', 'accumulate')),
      field('name', $.scoped_identifier),
      optional(choice($.wildcard_import, $.identifier)),
      optional(';'),
    )),

    wildcard_import: $ => token(seq('.', '*')),

    global_declaration: $ => prec.right(seq(
      'global',
      field('type', $.type_spec),
      field('name', $.identifier),
      optional(';'),
    )),

    declare_statement: $ => prec.right(choice(
      seq(
        'declare',
        'entry-point',
        field('name', choice($.string, $.identifier)),
        repeat($.annotation),
        optional(';'),
        'end',
        optional(';'),
      ),
      seq(
        'declare',
        'window',
        field('name', $.identifier),
        repeat($.lhs_pattern),
        'end',
        optional(';'),
      ),
      seq(
        'declare',
        'enum',
        field('name', $.scoped_identifier),
        repeat(choice(
          seq(commaSep1($.enum_constant), ';'),
          $.field_declaration,
          $.annotation,
        )),
        'end',
        optional(';'),
      ),
      seq(
        'declare',
        optional('trait'),
        field('name', $.scoped_identifier),
        optional(seq('extends', commaSep1($.scoped_identifier))),
        repeat(choice($.field_declaration, $.annotation)),
        'end',
        optional(';'),
      ),
    )),

    enum_constant: $ => seq(
      field('name', $.identifier),
      optional($.argument_list),
    ),

    field_declaration: $ => prec.right(seq(
      field('name', choice($.identifier, 'rule', 'query', 'window', 'duration', 'enabled')),
      ':',
      field('type', $.type_spec),
      repeat(choice(
        $.annotation,
        seq('=', $.expression),
      )),
      optional(';'),
    )),

    function_declaration: $ => prec.right(seq(
      'function',
      repeat(choice('public', 'private', 'protected', 'static', 'final', 'synchronized')),
      optional($.type_arguments),
      optional(field('return_type', $.type_spec)),
      field('name', $.identifier),
      '(',
      optional($.parameter_list),
      ')',
      optional(seq('throws', commaSep1($.scoped_identifier))),
      field('body', $.block),
      optional(';'),
    )),

    query_declaration: $ => prec.right(seq(
      'query',
      field('name', choice($.string, $.identifier)),
      optional(seq('(', optional($.parameter_list), ')')),
      repeat(choice($.lhs_pattern, ';')),
      'end',
      optional(';'),
    )),

    rule_declaration: $ => prec.right(seq(
      'rule',
      field('name', choice($.string, $.identifier, repeat1($.identifier))),
      repeat(choice(
        seq('extends', choice($.string, $.identifier)),
        seq('attributes', optional(':')),
        $.attribute,
        $.annotation,
        ',',
        ';',
      )),
      optional(seq(
        'when',
        optional(':'),
        optional(field('when', $.when_block)),
      )),
      'then',
      optional(seq('[', $.identifier, ']')),
      optional(':'),
      optional(field('rhs', $.rhs_block)),
      repeat($.named_consequence_section),
      'end',
      optional(';'),
    )),

    when_block: $ => repeat1(choice($.lhs_pattern, ';')),

    named_consequence_section: $ => seq(
      'then',
      '[',
      field('label', $.identifier),
      ']',
      optional(':'),
      optional(field('rhs', $.rhs_block)),
    ),

    attribute: $ => prec.right(seq(
      choice(
        seq('calendars', optional(':'), commaSep1($.string)),
        seq(
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
            'date-effective',
            'date-expires',
            'refract',
            'direct',
          )),
          optional(':'),
          optional(field('value', choice(
            $.parenthesized_raw,
            $.string,
            $.number,
            $.boolean,
            $.bound_variable,
            $.identifier,
          ))),
        ),
      ),
      optional(';'),
    )),

    parenthesized_raw: $ => seq(
      '(',
      repeat(choice(
        $.parenthesized_raw,
        $.string,
        $.number,
        $.boolean,
        $.bound_variable,
        $.identifier,
        '/',
        /[^()"'\/]+/,
      )),
      ')',
    ),

    lhs_pattern: $ => prec.right(choice(
      $.conditional_element,
      $.grouped_lhs_pattern,
      $.pattern_binding,
      $.oopath_expression,
      $.fact_pattern,
      $.accumulate_clause,
      $.groupby_clause,
      $.collect_clause,
      $.eval_clause,
      $.conditional_consequence,
      $.query_call,
      $.annotation,
    )),

    conditional_element: $ => prec.right(2, seq(
      field('kind', choice('and', 'or', 'not', 'exists', 'forall')),
      $.lhs_pattern,
    )),

    grouped_lhs_pattern: $ => prec.right(seq(
      '(',
      repeat1(choice($.lhs_pattern, ';')),
      ')',
    )),

    conditional_consequence: $ => prec.right(choice(
      seq(
        'if',
        '(',
        $.expression,
        ')',
        choice('do', 'break'),
        '[',
        $.identifier,
        ']',
        optional(seq('else', choice('do', 'break'), '[', $.identifier, ']')),
      ),
      seq(choice('do', 'break'), '[', $.identifier, ']'),
    )),

    query_call: $ => prec.right(seq(
      '?',
      field('name', choice($.identifier, $.string)),
      '(',
      optional(commaSep1($.constraint)),
      optional(seq(';', optional(commaSep1($.constraint)))),
      ')',
    )),

    pattern_binding: $ => prec.right(seq(
      $.variable_binding,
      choice(
        $.oopath_expression,
        $.fact_pattern,
        $.accumulate_clause,
        $.groupby_clause,
        $.collect_clause,
        $.grouped_lhs_pattern,
      ),
    )),

    variable_binding: $ => prec(3, seq(
      field('name', choice($.bound_variable, $.identifier)),
      choice(':', ':=', '=>'),
    )),

    oopath_expression: $ => prec.right(seq(
      choice('/', '?/'),
      $.oopath_segment,
      repeat(seq(choice('/', '?/', '.'), $.oopath_segment)),
      optional($.over_clause),
      optional($.from_clause),
    )),

    oopath_segment: $ => prec.right(seq(
      field('field', $.identifier),
      optional(seq('#', field('cast', $.scoped_identifier))),
      optional(choice(
        seq('[', optional(commaSep1($.constraint)), ']'),
        seq('(', optional(commaSep1($.constraint)), ')'),
      )),
    )),

    fact_pattern: $ => prec.right(seq(
      field('type', $.scoped_identifier),
      '(',
      optional(commaSep1($.constraint)),
      optional(seq(';', optional(commaSep1($.constraint)))),
      ')',
      repeat($.annotation),
      optional($.over_clause),
      optional($.from_clause),
    )),

    over_clause: $ => seq(
      'over',
      field('window', choice(
        seq(
          'window',
          ':',
          choice('time', 'length'),
          '(',
          commaSep1($.expression),
          ')',
        ),
        $.identifier,
      )),
    ),

    from_clause: $ => prec.right(seq(
      'from',
      choice(
        prec(2, seq('entry-point', choice($.string, $.identifier))),
        prec(2, seq('window', $.identifier)),
        $.accumulate_clause,
        $.groupby_clause,
        $.collect_clause,
        $.expression,
      ),
    )),

    collect_clause: $ => prec.right(seq(
      'collect',
      '(',
      $.lhs_pattern,
      ')',
    )),

    constraint: $ => choice(
      $.field_constraint,
      $.positional_constraint,
      seq(optional($.variable_binding), $.expression),
    ),

    field_constraint: $ => prec.right(2, seq(
      optional($.variable_binding),
      field('field', choice($.identifier, 'this', $.member_access, $.array_access)),
      field('operator', $.operator),
      field('value', $.expression),
      repeat(seq(
        choice('&&', '||'),
        optional(field('operator', $.operator)),
        $.expression,
      )),
    )),

    positional_constraint: $ => seq(
      field('index', $.number),
      ':',
      $.expression,
    ),

    operator: $ => prec.left(choice(
      '==', '!=', '>', '>=', '<', '<=', '~=',
      'matches', seq('not', 'matches'),
      'contains', seq('not', 'contains'),
      'memberOf', seq('not', 'memberOf'),
      'soundslike', seq('not', 'soundslike'),
      'in', 'notin', seq('not', 'in'),
      'excludes', seq('not', 'excludes'),
      seq(optional('not'), 'str', '[', $.identifier, ']'),
      seq(
        optional('not'),
        choice(
          'after', 'before', 'coincides', 'during', 'includes', 'includedby', 'finishes', 'finishedby',
          'meets', 'metby', 'overlaps', 'overlappedby', 'starts', 'startedby',
        ),
        optional(seq('[', commaSep1($.expression), ']')),
      ),
    )),

    accumulate_clause: $ => prec.right(seq(
      choice('accumulate', 'acc'),
      '(',
      repeat1($.lhs_pattern),
      choice(';', ','),
      choice(
        seq(
          commaSep1($.accumulate_function),
          optional(seq(';', optional(commaSep1($.constraint)))),
        ),
        $.accumulate_custom_block,
      ),
      ')',
    )),

    groupby_clause: $ => prec.right(seq(
      'groupby',
      '(',
      repeat1($.lhs_pattern),
      ';',
      optional($.variable_binding),
      $.expression,
      ';',
      commaSep1($.accumulate_function),
      optional(seq(';', optional(commaSep1($.constraint)))),
      ')',
    )),

    accumulate_function: $ => seq(
      optional($.variable_binding),
      field('name', choice(
        'sum', 'avg', 'average', 'min', 'max', 'count',
        'collectList', 'collectSet', 'collectArray',
        $.identifier,
      )),
      '(',
      optional(commaSep1($.expression)),
      ')',
    ),

    accumulate_custom_block: $ => seq(
      'init', '(', repeat($.rhs_statement), ')', ',',
      'action', '(', repeat($.rhs_statement), ')', ',',
      optional(seq('reverse', '(', repeat($.rhs_statement), ')', ',')),
      'result', '(', $.expression, ')',
      optional(';'),
    ),

    eval_clause: $ => prec.right(seq(
      'eval',
      '(',
      $.expression,
      optional(';'),
      ')',
    )),

    rhs_block: $ => repeat1(
      choice(
        $.rhs_action,
        $.rhs_statement,
      ),
    ),

    rhs_action: $ => prec.right(3, seq(
      field('name', choice('insert', 'insertLogical', 'modify', 'update', 'retract', 'delete')),
      '(',
      optional(commaSep1($.expression)),
      ')',
      optional($.block),
      optional(';'),
    )),

    rhs_statement: $ => prec.right(choice(
      $.variable_declaration,
      $.return_statement,
      $.throw_statement,
      $.break_statement,
      $.continue_statement,
      $.if_statement,
      $.for_statement,
      $.while_statement,
      $.do_while_statement,
      $.switch_statement,
      $.try_statement,
      $.block,
      seq($.expression, optional(choice(';', ','))),
      ';',
    )),

    variable_declaration: $ => prec.right(2, seq(
      repeat(choice('final', $.annotation)),
      field('type', $.type_spec),
      field('name', choice($.identifier, $.bound_variable, 'rule', 'query', 'window', 'duration', 'enabled')),
      optional(seq('=', $.expression)),
      repeat(seq(',', choice($.identifier, $.bound_variable), optional(seq('=', $.expression)))),
      optional(';'),
    )),

    return_statement: $ => prec.right(seq(
      'return',
      optional($.expression),
      optional(';'),
    )),

    throw_statement: $ => prec.right(seq(
      'throw',
      $.expression,
      optional(';'),
    )),

    break_statement: $ => prec.right(seq(
      'break',
      optional($.identifier),
      optional(';'),
    )),

    continue_statement: $ => prec.right(seq(
      'continue',
      optional($.identifier),
      optional(';'),
    )),

    if_statement: $ => prec.right(seq(
      'if',
      '(',
      $.expression,
      ')',
      $.rhs_statement,
      optional(seq('else', $.rhs_statement)),
    )),

    for_statement: $ => prec.right(seq(
      'for',
      '(',
      choice(
        seq(
          repeat(choice('final', $.annotation)),
          $.type_spec,
          choice($.identifier, $.bound_variable),
          choice(
            seq(':', $.expression),
            seq(
              optional(seq('=', $.expression)),
              repeat(seq(',', choice($.identifier, $.bound_variable), optional(seq('=', $.expression)))),
              ';',
              optional($.expression),
              ';',
              optional(commaSep1($.expression)),
            ),
          ),
        ),
        seq(optional(commaSep1($.expression)), ';', optional($.expression), ';', optional(commaSep1($.expression))),
      ),
      ')',
      $.rhs_statement,
    )),

    while_statement: $ => prec.right(seq(
      'while',
      '(',
      $.expression,
      ')',
      $.rhs_statement,
    )),

    do_while_statement: $ => prec.right(seq(
      'do',
      $.rhs_statement,
      'while',
      '(',
      $.expression,
      ')',
      optional(';'),
    )),

    switch_statement: $ => seq(
      'switch',
      '(',
      $.expression,
      ')',
      '{',
      repeat($.switch_case),
      '}',
    ),

    switch_case: $ => prec.right(seq(
      choice(
        seq('case', commaSep1($.expression), choice(':', '->')),
        seq('default', choice(':', '->')),
      ),
      repeat(choice($.rhs_action, $.rhs_statement)),
    )),

    try_statement: $ => prec.right(seq(
      'try',
      optional(seq('(', repeat1($.rhs_statement), ')')),
      $.block,
      repeat(seq('catch', '(', $.type_spec, repeat(seq('|', $.type_spec)), $.identifier, ')', $.block)),
      optional(seq('finally', $.block)),
    )),

    annotation: $ => prec.right(seq(
      '@',
      field('name', $.scoped_identifier),
      optional($.parenthesized_raw),
    )),

    parameter_list: $ => commaSep1($.parameter),

    parameter: $ => seq(
      repeat(choice('final', $.annotation)),
      optional(field('type', $.type_spec)),
      optional('...'),
      field('name', choice($.identifier, $.bound_variable)),
      repeat(seq('[', ']')),
    ),

    argument_list: $ => seq(
      '(',
      optional(commaSep1($.expression)),
      ')',
    ),

    block: $ => seq(
      '{',
      repeat(choice($.rhs_action, $.rhs_statement)),
      '}',
    ),

    expression: $ => choice(
      $.bound_variable,
      $.identifier,
      'this',
      'rule',
      'query',
      'window',
      'duration',
      'enabled',
      $.number,
      $.string,
      $.boolean,
      $.null_literal,
      $.new_expression,
      $.cast_expression,
      $.lambda_expression,
      $.unary_expression,
      $.assignment_expression,
      $.member_access,
      $.array_access,
      $.call_expression,
      $.binary_expression,
      $.ternary_expression,
      $.parenthesized_expression,
      $.array_initializer,
    ),

    new_expression: $ => prec.right(4, seq(
      'new',
      $.type_spec,
      choice(
        seq('(', optional(commaSep1($.expression)), ')', optional($.block)),
        seq(repeat1(seq('[', $.expression, ']')), repeat(seq('[', ']'))),
        $.array_initializer,
      ),
    )),

    array_initializer: $ => seq(
      '{',
      optional(commaSep1($.expression)),
      optional(','),
      '}',
    ),

    cast_expression: $ => prec.right(4, seq(
      '(',
      $.type_spec,
      ')',
      $.expression,
    )),

    lambda_expression: $ => prec.right(1, seq(
      choice(
        $.identifier,
        $.bound_variable,
        seq('(', optional($.parameter_list), ')'),
      ),
      '->',
      choice($.expression, $.block),
    )),

    unary_expression: $ => prec.right(3, choice(
      seq(choice('!', '-', '+', '~', '++', '--', '==', '!=', '<', '<=', '>', '>=', '~='), $.expression),
      seq($.expression, choice('++', '--')),
    )),

    assignment_expression: $ => prec.right(1, seq(
      $.expression,
      choice('=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=', '>>>='),
      $.expression,
    )),

    ternary_expression: $ => prec.right(1, seq(
      $.expression,
      '?',
      $.expression,
      ':',
      $.expression,
    )),

    member_access: $ => prec.left(4, seq(
      $.expression,
      choice('.', '?.', '!.', '::', '.#', '#'),
      choice($.identifier, 'class', 'this', 'rule', 'query', 'end', 'when', 'then', 'from', 'in'),
    )),

    array_access: $ => prec.left(4, seq(
      $.expression,
      '[',
      $.expression,
      ']',
    )),

    call_expression: $ => prec.left(4, seq(
      $.expression,
      '(',
      optional(commaSep1($.expression)),
      ')',
    )),

    binary_expression: $ => prec.left(2, seq(
      $.expression,
      choice(
        '+', '-', '*', '/', '%',
        '&&', '||', '&', '|', '^',
        '==', '!=', '<', '<=', '>', '>=', '~=', '<=>',
        '<<', '>>', '>>>',
        'instanceof',
        $.operator,
      ),
      $.expression,
    )),

    parenthesized_expression: $ => seq(
      '(',
      commaSep1($.expression),
      ')',
    ),

    type_spec: $ => prec.right(seq(
      $.scoped_identifier,
      optional($.type_arguments),
      repeat(seq('[', ']')),
    )),

    type_arguments: $ => seq(
      '<',
      optional(commaSep1(choice(
        $.type_spec,
        seq('?', optional(seq(choice('extends', 'super'), $.type_spec))),
      ))),
      '>',
    ),

    scoped_identifier: $ => prec.right(seq(
      $.identifier,
      repeat(seq('.', $.identifier)),
    )),

    type_identifier: $ => $.type_spec,

    bound_variable: $ => /\$[a-zA-Z_][a-zA-Z0-9_$]*/,

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_$]*/,

    number: $ => /\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d[\d_]*)?([fFdDlLbBiI]|(ms|[dhms])(\d+(ms|[dhms]))*)?|0[xX][0-9a-fA-F_]+[lL]?|0[bB][01_]+[lL]?/,

    string: $ => choice(
      seq('"""', repeat(choice(/[^"\\]/, /\\./, /"[^"]/, /""[^"]/)), '"""'),
      seq('"', repeat(choice(/[^"\\]/, /\\./)), '"'),
      seq("'", repeat(choice(/[^'\\]/, /\\./)), "'"),
    ),

    boolean: $ => choice('true', 'false'),

    null_literal: $ => 'null',

    line_comment: $ => token(seq('//', /.*/)),

    hash_comment: $ => token(seq('#', /[ \t#].*/)),

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
