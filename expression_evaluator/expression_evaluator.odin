package expression_evaluator

import "core:math"
import "core:strconv"
import "core:unicode"

DIVISION_BY_ZERO_RETURNS_ZERO :: #config(DIVISION_BY_ZERO_RETURNS_ZERO, false)

NAN :: math.INF_F32 + math.NEG_INF_F32

Operator :: rune

PrecedenceMap :: map[Operator]int
OperatorMap :: map[rune]OperatorFunction

VariableMap :: map[Identifier]Number

make_default_precedence_map :: proc(allocator := context.allocator) -> PrecedenceMap {
	result := make(PrecedenceMap, allocator = allocator)
	result['+'] = 1
	result['-'] = 1
	result['*'] = 2
	result['/'] = 2
	return result
}

VariableNotFound :: struct {
	name: string,
}

OperatorError :: struct {
	operator: Operator,
	err:      string,
}

UnexpectedToken :: struct {
	token: Token,
}

InvalidCharacter :: struct {
	character: rune,
}

IncompleteExpression :: struct {
}

ParseError :: union {
	InvalidCharacter,
	IncompleteExpression,
}

when !DIVISION_BY_ZERO_RETURNS_ZERO {
	DivisionByZero :: struct {
	}
}

EvalError :: union {
		OperatorError,
		VariableNotFound,
		UnexpectedToken,
	} when DIVISION_BY_ZERO_RETURNS_ZERO else union {
		OperatorError,
		VariableNotFound,
		UnexpectedToken,
		DivisionByZero,
	}

EvalResult :: union {
	f32,
	EvalError,
}

Error :: union #shared_nil {
	EvalError,
	ParseError,
}

OperatorFunction :: proc(a: f32, b: f32) -> EvalResult

make_default_operator_map :: proc(allocator := context.allocator) -> OperatorMap {
	result := make(OperatorMap, allocator = allocator)
	result['+'] = proc(a: f32, b: f32) -> EvalResult {return a + b}
	result['-'] = proc(a: f32, b: f32) -> EvalResult {return a - b}
	result['*'] = proc(a: f32, b: f32) -> EvalResult {return a * b}
	result['/'] = proc(a: f32, b: f32) -> EvalResult {
		if b == 0.0 {
			if DIVISION_BY_ZERO_RETURNS_ZERO {
				return f32(0.0)
			} else {
				return EvalError(OperatorError{'/', "Division by zero"})
			}
		}
		return a / b
	}
	return result
}

@(private)
Paren :: enum {
	Open,
	Close,
}

Number :: union {
	f16,
	f32,
	i8,
	i16,
	i32,
	int,
	u8,
	u16,
	u32,
	uint,
}
Identifier :: string

@(private)
Token :: union {
	Number,
	Paren,
	Identifier,
	Operator,
}


@(private)
lex :: proc(text: string, tokens: []Token, allocator := context.allocator) -> (err: Error) {
	index := 0
	i := 0
	for i < len(text) {
		ch := text[i]
		switch ch {
		case '.':
			inner := text[i:]
			count := 0
			for count < len(inner) && unicode.is_digit(rune(inner[count])) {
				count += 1
			}
			tokens[index] = Number(f32(strconv.atof(inner[:count])))
			index += 1
			i += count
		case '-', '0' ..= '9':
			inner := text[i:]
			count := 0
			if ch == '-' {
				if tokens[index - 1] != Paren.Open && tokens[index - 1] != Operator('(') {
					tokens[index] = Operator(ch)
					index += 1
					i += 1
					continue
				}
				count = 1
			}
			has_dot := false
			for count < len(inner) &&
			    (unicode.is_digit(rune(inner[count])) || inner[count] == '.') {
				if inner[count] == '.' {
					has_dot = true
				}
				count += 1
			}
			if has_dot {
				tokens[index] = Number(f32(strconv.atof(inner[:count])))
				index += 1
			} else {
				tokens[index] = Number(i32(strconv.atoi(inner[:count])))
				index += 1
			}
			i += count
		case '(':
			tokens[index] = Paren.Open
			index += 1
			i += 1
		case ')':
			tokens[index] = Paren.Close
			index += 1
			i += 1
		case 'a' ..= 'z', 'A' ..= 'Z', '_':
			inner := text[i:]
			count := 0
			for count < len(inner) &&
			    (unicode.is_letter(rune(inner[count])) ||
					    inner[count] == '_' ||
					    inner[count] == '.' ||
					    unicode.is_digit(rune(inner[count]))) {
				count += 1
			}
			tokens[index] = Identifier(inner[:count])
			index += 1
			i += count
		case ' ', '\t', '\n', '\r':
			i += 1 // Skip whitespace
		case:
			if unicode.is_symbol(rune(ch)) || unicode.is_punct(rune(ch)) {
				tokens[index] = Operator(ch)
				index += 1
				i += 1
				continue
			}
			err = ParseError(InvalidCharacter{rune(ch)})
			return
		}
	}
	return
}

@(private)
Binary :: struct {
	op:    rune,
	left:  int,
	right: int,
}

@(private)
Literal :: struct {
	value: Number,
}

@(private)
Variable :: struct {
	name: string,
}

@(private)
Expr :: union {
	Binary,
	Literal,
	Variable,
}

@(private)
Parser :: struct {
	tokens:     []Token,
	precedence: map[Operator]int,
	pos:        int,
}

@(private)
next_token :: proc(p: ^Parser) -> Token {
	if p.pos >= len(p.tokens) {
		return nil
	}
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

@(private)
peek_token :: proc(p: ^Parser) -> Token {
	if p.pos >= len(p.tokens) {
		return nil
	}
	return p.tokens[p.pos]
}

@(private)
expect_token :: proc(p: ^Parser, expected: Token) -> Token {
	t := peek_token(p)
	if t == expected {
		return next_token(p)
	}
	return nil
}

@(private)
parse_primary :: proc(p: ^Parser, eb: ^ExpressionBlock) -> (id: int, err: ParseError) {
	id = -1
	if expect_token(p, Paren.Open) != nil {
		id = parse_expr_with_precedence(p, eb, 0) or_return

		if expect_token(p, Paren.Close) == nil {
			panic("Expected closing parenthesis")
		}
		return
	}
	tok := next_token(p)
	#partial switch t in tok {
	case Identifier:
		eb.expressions[eb.index] = Variable{t}
		id = eb.index
		eb.index += 1
	case Number:
		eb.expressions[eb.index] = Literal{t}
		id = eb.index
		eb.index += 1
	}
	if id == -1 {
		err = IncompleteExpression{}
	}
	return
}

@(private)
parse_expr_with_precedence :: proc(
	p: ^Parser,
	eb: ^ExpressionBlock,
	min_precedence: int,
) -> (
	id: int,
	err: ParseError,
) {
	left := parse_primary(p, eb) or_return
	for {
		peeked := peek_token(p)
		if peeked == nil {
			break
		}

		op: rune

		if par, ok := peeked.(Paren); ok {
			if par == Paren.Close {
				break
			} else {
				op = '*'
			}
		} else {
			op, ok = peeked.(Operator)
			if !ok {
				break
			}
		}

		if op not_in p.precedence do break
		precedence := p.precedence[op]

		if precedence < min_precedence do break

		_ = next_token(p) // consume operator

		right := parse_expr_with_precedence(p, eb, precedence + 1) or_return

		eb.expressions[eb.index] = Binary{op, left, right}
		left = eb.index
		eb.index += 1
	}

	id = left

	return
}

destroy_expr :: proc(e: ExpressionBlock) {
	delete(e.expressions)
}

ExpressionBlock :: struct {
	start:       int,
	index:       int,
	expressions: []Expr,
}

@(private)
TokenBlock :: struct {
	index:       int,
	expressions: []Expr,
}

@(private)
TokenType :: enum {
	None,
	Number,
	Identifier,
}

@(private)
count_tokens :: proc(input: string) -> int {
	last_token_type := TokenType.None
	token_count := 0
	for c in input {
		if c == '.' &&
		   (last_token_type == TokenType.Number || last_token_type == TokenType.Identifier) {
			continue
		}

		if unicode.is_space(c) {
			last_token_type = TokenType.None
		} else if unicode.is_digit(c) {
			if last_token_type == TokenType.Identifier {
				continue
			}
			if last_token_type != TokenType.Number {
				last_token_type = TokenType.Number
				token_count += 1
			}
		} else if unicode.is_letter(c) || c == '_' {
			if last_token_type != TokenType.Identifier {
				last_token_type = TokenType.Identifier
				token_count += 1
			}
		} else if unicode.is_symbol(c) || unicode.is_punct(c) {
			token_count += 1
			last_token_type = TokenType.None
		}
	}
	return token_count
}

@(require_results)
parse :: proc(
	input: string,
	precedence_map: Maybe(PrecedenceMap) = nil,
	allocator := context.allocator,
) -> (
	eb: ExpressionBlock,
	err: Error,
) {
	pm := precedence_map.? or_else make_default_precedence_map()
	defer if precedence_map == nil do delete(pm)
	token_count := count_tokens(input)
	tokens: []Token = make([]Token, token_count, allocator = allocator)
	defer delete(tokens)
	lex(input, tokens) or_return

	eb = {0, 0, make([]Expr, len(tokens), allocator = allocator)}
	defer if err != nil do destroy_expr(eb)

	parser := Parser {
		tokens     = tokens[:],
		pos        = 0,
		precedence = pm,
	}
	eb.start = parse_expr_with_precedence(&parser, &eb, 0) or_return
	return
}

@(private)
value_to_float :: proc(n: Number) -> f32 {
	#partial switch n in n {
	case f16:
		return f32(n)
	case f32:
		return n
	case i8:
		return f32(n)
	case i16:
		return f32(n)
	case i32:
		return f32(n)
	case int:
		return f32(n)
	case u8:
		return f32(n)
	case u16:
		return f32(n)
	case u32:
		return f32(n)
	case uint:
		return f32(n)
	}
	panic("Invalid number type")
}

@(private)
internal_eval_expr :: proc(
	expr: Expr,
	eb: ExpressionBlock,
	operators: OperatorMap,
	variables: Maybe(VariableMap),
) -> (
	result: f32,
	err: EvalError,
) #no_bounds_check {
	defer if err != nil do result = NAN

	#partial switch e in expr {
	case Literal:
		result = value_to_float(e.value)
	case Variable:
		vars, ok := variables.(VariableMap)
		if !ok {
			err = VariableNotFound{e.name}
			return
		}
		v: Number
		if v, ok = vars[e.name]; ok {
			result = value_to_float(v)
		} else {

			err = VariableNotFound{e.name}
		}
	case Binary:
		left: f32
		right: f32
		left = internal_eval_expr(eb.expressions[e.left], eb, operators, variables) or_return
		right = internal_eval_expr(eb.expressions[e.right], eb, operators, variables) or_return
		if op, ok := operators[e.op]; ok {
			tmp := op(left, right)
			if result, ok = tmp.(f32); ok {
				return
			}
			err = tmp.(EvalError)
		} else {
			err = UnexpectedToken{Operator(e.op)}
		}
	}
	return
}

@(require_results)
eval_expr :: proc(
	eb: ExpressionBlock,
	variables: Maybe(VariableMap) = nil,
	operators: Maybe(OperatorMap) = nil,
	allocator := context.allocator,
) -> (
	result: f32,
	err: Error,
) #no_bounds_check {
	op := operators.? or_else make_default_operator_map()
	defer if operators == nil do delete(op)
	return internal_eval_expr(eb.expressions[eb.start], eb, op, variables)
}

@(require_results)
eval :: proc(
	text: string,
	variables: Maybe(VariableMap) = nil,
	operators: Maybe(OperatorMap) = nil,
	precedence_map: Maybe(PrecedenceMap) = nil,
	allocator := context.allocator,
) -> (
	f: f32,
	err: Error,
) {
	expr := parse(text, precedence_map, allocator = allocator) or_return
	defer destroy_expr(expr)

	return eval_expr(expr, variables, operators, allocator = allocator)
}
