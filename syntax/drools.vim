" Vim syntax file
" Language:    Drools Rule Language (.drl, .dsl)
" Maintainer:  drools.nvim contributors

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Comments
syn region  droolsCommentLine   start="//" end="$" contains=@Spell
syn region  droolsCommentLine   start="^\s*#" end="$" contains=@Spell
syn region  droolsCommentBlock  start="/\*" end="\*/" contains=@Spell

" Top-level Directives & Structure Keywords
syn keyword droolsStructure     package import global declare trait enum window query function rule end unit extends
syn keyword droolsSection       when then

" Rule Attributes
syn keyword droolsAttribute     salience agenda-group ruleflow-group activation-group
syn keyword droolsAttribute     lock-on-active no-loop auto-focus enabled dialect
syn keyword droolsAttribute     duration timer calendars date-effective date-expires refract direct

" LHS Conditional & Pattern Keywords
syn keyword droolsConditional   and or not exists forall eval from over
syn keyword droolsConditional   accumulate collect entry-point
syn keyword droolsOperator      matches memberOf soundslike in excludes str
syn match   droolsOperator      "\<contains\>"

" Complex Event Processing (CEP) & Temporal Operators
syn keyword droolsTemporal      after before coincides during finishes finishedby meets metby overlaps overlappedby starts startedby
syn match   droolsWindow        "window:\%(time\|length\)"
syn match   droolsTemporalOffset "\[\s*-\?\d\+[smhd]s\?\s*\%(,\s*-\?\d\+[smhd]s\?\s*\)\?\]"

" Accumulate Built-in Functions & Clauses
syn keyword droolsAccumulateFunc sum avg min max count collectList collectSet collectArray average
syn keyword droolsAccumulateClause init action reverse result

" Built-in Constants & Literals
syn keyword droolsBoolean       true false
syn keyword droolsConstant      null

" Fact Types (Capitalized identifiers preceding constraint parens)
syn match   droolsFactType      "\<[A-Z][a-zA-Z0-9_]*\>\ze\s*("

" Variables (Bound variables start with $)
syn match   droolsVariable      "\$[a-zA-Z_][a-zA-Z0-9_$]*"
syn match   droolsBindingOp     ":=\?"

" Numbers & Temporal Durations
syn match   droolsNumber        "\<\d[\d_]*\%([LlfFdDbBiI]\|ms\|[dhms]\)\?\>"
syn match   droolsNumber        "\<\d[\d_]*\.\d[\d_]*\%([eE][+-]\?\d[\d_]*\)\?[fFdDbB]\?\>"
syn match   droolsNumber        "0[xX][0-9a-fA-F_]\+[lL]\?"
syn match   droolsNumber        "0[bB][01_]\+[lL]\?"

" Strings & Multiline Text Blocks
syn region  droolsString        start='"""' end='"""' contains=@Spell
syn region  droolsString        start='"' skip='\\\\\|\\"' end='"' contains=@Spell
syn region  droolsString        start="'" skip="\\\\\|\\'" end="'" contains=@Spell

" Type Declarations & Annotations
syn match   droolsAnnotation    "@[a-zA-Z_][a-zA-Z0-9_.]*"
syn keyword droolsKnownAnnotation @role @timestamp @duration @expires @key @position @propertyChangeSupport @format @classReactive @propertyReactive @watch

" RHS Block & Java/MVEL Embedded Highlighting
syn keyword droolsRHSKeyword    insert insertLogical modify update retract delete
syn keyword droolsRHSKeyword    drools kcontext system System entryPoints channels
syn keyword droolsJavaKeyword   new return if else for while do switch case default break continue try catch finally throw throws instanceof class interface var final public private protected static synchronized void int long double float boolean char byte short String Object List Map Set

" DSL File constructs ([when], [then], {variable})
syn match   droolsDSLHeader     "^\[\%(when\|then\|keyword\|condition\|consequence\)\?\]"
syn match   droolsDSLParam      "{\w\+}"

" Highlight links
hi def link droolsCommentLine   Comment
hi def link droolsCommentBlock  Comment
hi def link droolsStructure     Keyword
hi def link droolsSection       Statement
hi def link droolsAttribute     PreProc
hi def link droolsConditional   Conditional
hi def link droolsOperator      Operator
hi def link droolsTemporal      Operator
hi def link droolsWindow        Special
hi def link droolsTemporalOffset Number
hi def link droolsAccumulateFunc Function
hi def link droolsAccumulateClause Keyword
hi def link droolsBoolean       Boolean
hi def link droolsConstant      Constant
hi def link droolsFactType      Type
hi def link droolsVariable      Identifier
hi def link droolsBindingOp     Delimiter
hi def link droolsNumber        Number
hi def link droolsString        String
hi def link droolsAnnotation    Special
hi def link droolsKnownAnnotation StorageClass
hi def link droolsRHSKeyword    Function
hi def link droolsJavaKeyword   Keyword
hi def link droolsDSLHeader     PreProc
hi def link droolsDSLParam      Special

let b:current_syntax = "drools"

let &cpo = s:cpo_save
unlet s:cpo_save
