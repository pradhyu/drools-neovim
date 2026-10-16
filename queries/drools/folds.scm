;; queries/drools/folds.scm
;; Tree-sitter fold queries for Drools Rule Language

(rule_declaration) @fold
(when_block) @fold
(rhs_block) @fold
(declare_statement) @fold
(query_declaration) @fold
(function_declaration) @fold
(block) @fold
(block_comment) @fold
