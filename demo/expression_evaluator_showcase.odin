#+feature dynamic-literals

package demo

import ee "../expression_evaluator"

import "core:log"
import "core:math"

when RUN_EE_DEMO {
	showcase_expression_evaluator :: proc() {
		precedence := ee.make_default_precedence_map()
		defer delete(precedence)

		precedence['^'] = 3

		eb, e := ee.parse("2 ^ (2 + foo) * 4", precedence)
		assert(e == nil)
		defer ee.destroy_expr(eb)

		operators := ee.make_default_operator_map()
		defer delete(operators)

		operators['^'] = proc(a: f32, b: f32) -> ee.EvalResult {return math.pow(a, b)}

		variables := map[string]ee.Number {
			"foo" = int(3),
		}
		defer delete(variables)

		f: f32 = 0.0
		f, e = ee.eval_expr(eb, variables, operators)

		assert(e == nil)

		log.info("Result:", f)
	}
}
