const std = @import("std");
const _cli = @import("cli");
const AppRunner = _cli.AppRunner;
const Command = _cli.Command;
const Option = _cli.Option;
const Target = _cli.CommandTarget;
const Action = _cli.CommandAction;
const PositionalArgs = _cli.PositionalArgs;
const PositionalArg = _cli.PositionalArg;

const a = .{
	Command{
		.name = "build",
		.target = Target{
			.action = Action{
				.positional_args = PositionalArgs{
					.required = 
				}
			}
		}
	}
};

pub fn main() !void {
	const runner = AppRunner.init(std.heap.page_allocator);

	runner.allocCommands(args: []const command.Command)
}