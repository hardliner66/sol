package demo

import r "../rustic"

import "core:fmt"

when RUN_RUSTIC_DEMO {
	showcase_rustic :: proc() {
		res: r.Result(int, string) = r.ok(42)
		opt: Maybe(int) = 5

		fmt.printfln("Result: %v", r.unwrap(res))
		fmt.printfln("Result: %v", r.unwrap(opt))
	}
}
