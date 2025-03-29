#+feature dynamic-literals

package expression_evaluator

import "core:testing"

equal :: proc(a, b: f32) -> bool {
	return abs(a - b) < 0.000001
}

@(test)
test_basic_arithmetic :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("1 + 2")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 3), "Expected 1 + 2 to equal 3, got %v", result)

	result, err = eval("10 - 4")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 6), "Expected 10 - 4 to equal 6, got %v", result)

	result, err = eval("3 * 5")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 15), "Expected 3 * 5 to equal 15, got %v", result)

	result, err = eval("8 / 2")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 4), "Expected 8 / 2 to equal 4, got %v", result)

	when DIVISION_BY_ZERO_RETURNS_ZERO {
		result, err = eval("1 / 0")
		testing.expectf(t, err == nil, "Expected no error, got %v", err)
		testing.expectf(t, equal(result, 0), "Expected 1 / 0 to equal 0, got %v", result)
	}
}

@(test)
test_operator_precedence :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("1 + 2 * 3")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 7), "Expected 1 + 2 * 3 to equal 7, got %v", result)

	result, err = eval("10 / 2 + 3")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 8), "Expected 10 / 2 + 3 to equal 8, got %v", result)
}

@(test)
test_parentheses :: proc(t: ^testing.T) {
	result: f32
	err: Error

	result, err = eval("(1 + 2) * 3")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 9), "Expected (1 + 2) * 3 to equal 9, got %v", result)

	result, err = eval("10 / (2 + 3)")
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 2), "Expected 10 / (2 + 3) to equal 2, got %v", result)
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
	testing.expectf(t, err == nil, "Expected no error, got %v", err)
	testing.expectf(t, equal(result, 8), "Expected x + y to equal 8, got %v", result)

	result, err = eval("x * y", variables)
	testing.expectf(t, err == nil, "Expected no error, got %v")
	testing.expectf(t, equal(result, 15), "Expected x * y to equal 15, got %v", result)
}

@(test)
test_error_handling :: proc(t: ^testing.T) {
	result: f32
	err: Error

	when !DIVISION_BY_ZERO_RETURNS_ZERO {
		_, err = eval("1 / 0")
		testing.expectf(t, err != nil, "Expected an error for division by zero")
	}

	_, err = eval("unknown_var + 1")
	testing.expectf(t, err != nil, "Expected an error for unknown variable")

	_, err = eval("1 +")
	testing.expectf(t, err != nil, "Expected an error for incomplete expression")
}
