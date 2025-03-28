#+feature dynamic-literals

package expression_evaluator

import "core:strconv"
import "core:unicode"


Operator :: rune

@(private)
MakeDefaultPrecedenceMap :: proc() -> map[Operator]int {
	return map[Operator]int{'+' = 1, '-' = 1, '*' = 2, '/' = 2}
}

DefaultPrecedenceMap := MakeDefaultPrecedenceMap()

OpProc :: proc(a: f32, b: f32) -> f32

DefaultOpProcMap := map[rune]OpProc {
	'+' = proc(a: f32, b: f32) -> f32 {return a + b},
	'-' = proc(a: f32, b: f32) -> f32 {return a - b},
	'*' = proc(a: f32, b: f32) -> f32 {return a * b},
	'/' = proc(a: f32, b: f32) -> f32 {return a / b},
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

InvalidCharacter :: struct {
	character: rune,
}

NoMoreTokens :: struct {
}

UnexpectedToken :: struct {
	token: Token,
}

VariableNotFound :: struct {
	name: Identifier,
}

Error :: union {
	NoMoreTokens,
	InvalidCharacter,
	UnexpectedToken,
	VariableNotFound,
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
			delete(tokens)
			err = InvalidCharacter{rune(ch)}
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
parse_primary :: proc(p: ^Parser, eb: ^ExpressionBlock) -> (id: int, err: Error) {
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
	return
}

@(private)
parse_expr_with_precedence :: proc(
	p: ^Parser,
	eb: ^ExpressionBlock,
	min_precedence: int,
) -> (
	id: int,
	err: Error,
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

@(require_results)
parse :: proc(
	input: string,
	precedence_map := DefaultPrecedenceMap,
) -> (
	eb: ExpressionBlock,
	err: Error,
) {
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
	tokens: []Token = make([]Token, token_count)
	defer delete(tokens)
	lex(input, tokens) or_return

	eb = {0, 0, make([]Expr, len(tokens))}

	parser := Parser {
		tokens     = tokens[:],
		pos        = 0,
		precedence = precedence_map,
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
	variables: map[Identifier]Number,
	operators: map[Operator]OpProc,
) -> (
	result: f32,
	err: Error,
) #no_bounds_check {
	#partial switch e in expr {
	case Literal:
		result = value_to_float(e.value)
	case Variable:
		if v, ok := variables[e.name]; ok {
			result = value_to_float(v)
		} else {

			err = VariableNotFound{e.name}
		}
	case Binary:
		left: f32
		right: f32
		left = internal_eval_expr(eb.expressions[e.left], eb, variables, operators) or_return
		right = internal_eval_expr(eb.expressions[e.right], eb, variables, operators) or_return
		if op, ok := operators[e.op]; ok {
			result = op(left, right)
		} else {
			err = UnexpectedToken{Operator(e.op)}
		}
	}
	return
}

@(require_results)
eval_expr :: proc(
	eb: ExpressionBlock,
	variables: map[Identifier]Number = {},
	operators := DefaultOpProcMap,
) -> (
	result: f32,
	err: Error,
) #no_bounds_check {
	return internal_eval_expr(eb.expressions[eb.start], eb, variables, operators)
}

@(require_results)
eval :: proc(
	text: string,
	variables: map[Identifier]Number = {},
	operators := DefaultOpProcMap,
	precedence_map := DefaultPrecedenceMap,
) -> (
	f: f32,
	err: Error,
) {
	expr := parse(text, precedence_map) or_return
	defer destroy_expr(expr)

	return eval_expr(expr, variables, operators)
}
