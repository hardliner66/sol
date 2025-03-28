#+feature dynamic-literals

package expression_evaluator

import "core:testing"

@(test)
test_basic_arithmetic :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("1 + 2")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 3, "Expected 1 + 2 to equal 3")

	result, err = eval("10 - 4")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 6, "Expected 10 - 4 to equal 6")

	result, err = eval("3 * 5")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 15, "Expected 3 * 5 to equal 15")

	result, err = eval("8 / 2")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 4, "Expected 8 / 2 to equal 4")

	when DIVISION_BY_ZERO_RETURNS_ZERO {
		result, err = eval("1 / 0")
		testing.expect(t, err == nil, "Expected no error")
		testing.expect(t, result == 0, "Expected 1 / 0 to equal 0")
	}
}

@(test)
test_operator_precedence :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("1 + 2 * 3")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 7, "Expected 1 + 2 * 3 to equal 7")

	result, err = eval("10 / 2 + 3")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 8, "Expected 10 / 2 + 3 to equal 8")
}

@(test)
test_parentheses :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("(1 + 2) * 3")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 9, "Expected (1 + 2) * 3 to equal 9")

	result, err = eval("10 / (2 + 3)")
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 2, "Expected 10 / (2 + 3) to equal 2")
}

@(test)
test_variables :: proc(t: ^testing.T) {
	result: f32
	err: Error

	variables := map[Identifier]Number {
		"x" = int(5),
		"y" = int(3),
	}
	defer delete(variables)

	result, err = eval("x + y", variables)
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 8, "Expected x + y to equal 8")

	result, err = eval("x * y", variables)
	testing.expect(t, err == nil, "Expected no error")
	testing.expect(t, result == 15, "Expected x * y to equal 15")
}

@(test)
test_error_handling :: proc(t: ^testing.T) {
	result: f32
	err: Error

	when !DIVISION_BY_ZERO_RETURNS_ZERO {
		_, err = eval("1 / 0")
		testing.expect(t, err != nil, "Expected an error for division by zero")
	}

	_, err = eval("unknown_var + 1")
	testing.expect(t, err != nil, "Expected an error for unknown variable")

	_, err = eval("1 +")
	testing.expect(t, err != nil, "Expected an error for incomplete expression")
}
