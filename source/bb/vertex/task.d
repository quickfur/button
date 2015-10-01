/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.vertex.task;

/**
 * A task identifier.
 */
alias TaskId = immutable(string)[];

/**
 * The result of executing a task.
 */
struct TaskResult
{
    // The task exit status code
    int status;

    // The standard output and standard error of the task.
    const(ubyte)[] output;

    // The list of implicit dependencies sent back
    string[] inputs, outputs;
}

/**
 * Escapes the argument according to the rules of bash, the most commonly used
 * shell.
 *
 * An argument is surrounded with double quotes if it contains any special
 * characters. A backslash is always escaped with another backslash.
 */
private string escapeShellArg(string arg) pure nothrow
{
    // TODO
    return arg;
}

/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;
    import std.datetime : SysTime;

    /**
     * The command to execute. The first argument is the name of the executable.
     */
    TaskId command;

    /**
     * Text to display when running the command. If this is null, the command
     * itself will be displayed. This is useful for reducing the amount of
     * information that is displayed.
     */
    //string display;

    /**
     * Time this task was last executed. If this is SysTime.min, then it is
     * taken to mean that the task has never been executed before. This is
     * useful for knowing if a task with no dependencies needs to be executed.
     */
    SysTime lastExecuted = SysTime.min;

    // TODO: Store last execution duration.

    /**
     * Returns a string representation of the command.
     *
     * Since commands are specified as arrays, we format it into a string as one
     * would enter into a shell.
     */
    string toString() const pure nothrow
    {
        import std.array : join;
        import std.algorithm.iteration : map;

        //if (display) return display;

        return command.map!(arg => arg.escapeShellArg).join(" ");
    }

    /**
     * Returns a short string representation of the command.
     */
    @property string shortString() const pure nothrow
    {
        if (command.length > 0)
            return command[0];

        return "";
    }

    /**
     * Returns the unique identifier for this vertex.
     */
    @property inout(TaskId) identifier() inout pure nothrow
    {
        return command;
    }

    /**
     * Compares this task with another.
     */
    int opCmp()(const auto ref typeof(this) rhs) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        return cmp(this.command, rhs.command);
    }

    unittest
    {
        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) == Task(["a", "b"]));
    }

    /**
     * Executes a task.
     */
    version (Posix) TaskResult execute() const
    {
        import core.sys.posix.unistd;
        import core.sys.posix.sys.wait;
        import core.stdc.errno;

        import io.file.pipe : pipe;
        import io.file.stream : sysEnforce, SysException;

        import std.array : appender;

        import io;

        TaskResult result;

        auto std = pipe(); // Standard output
        auto deps = pipe(); // Implicit dependencies

        immutable pid = fork();
        sysEnforce(pid >= 0, "Failed to fork current process");

        // Child process
        if (pid == 0)
        {
            std.readEnd.close();
            deps.readEnd.close();
            executeChild(command, std.writeEnd.handle, deps.writeEnd.handle);
        }

        // In the parent process
        std.writeEnd.close();
        deps.writeEnd.close();

        // Read output
        ubyte[4096] buf;
        auto output = appender!(ubyte[]);

        foreach (chunk; std.readEnd.byChunk(buf))
            output.put(chunk);

        // TODO: Read dependencies from pipe

        std.readEnd.close();
        deps.readEnd.close();

        // Wait for the child to exit
        while (true)
        {
            int status;
            immutable check = waitpid(pid, &status, 0) == -1;
            if (check == -1)
            {
                if (errno == ECHILD)
                {
                    throw new SysException("Child process does not exist");
                }
                else
                {
                    // Keep waiting
                    assert(errno == EINTR);
                    continue;
                }
            }

            if (WIFEXITED(status))
            {
                result.status = WEXITSTATUS(status);
                break;
            }
            else if (WIFSIGNALED(status))
            {
                result.status = -WTERMSIG(status);
                break;
            }
        }

        // TODO: Time how long the process takes to execute
        result.output = output.data;
        return result;
    }

    version (Windows)
    TaskResult execute() const
    {
        // TODO: Implement implicit dependencies
        import std.process : execute;

        auto cmd = execute(command);

        return TaskResult(cmd.status, cast(const(ubyte)[])cmd.output);
    }
}

version (Posix)
private void executeChild(in char[][] command, int stdfd, int depsfd)
{
    import std.format : format;
    import std.conv : to;
    import std.string : toStringz;

    import core.sys.posix.unistd;
    import core.stdc.stdlib : malloc, free;
    import core.sys.posix.stdlib : setenv;
    import core.sys.posix.stdio : perror;

    import io.file.stream : SysException;

    // Close standard input because it won't be possible to write to it when
    // multiple tasks are running simultaneously.
    //close(STDIN_FILENO);

    // Convert D command argument list to a null-terminated argument list
    auto argv = cast(const(char)**)malloc(
            (command.length + 1) * (char*).sizeof
            );
    scope (exit) free(argv); // Probably doesn't matter if this gets freed

    size_t i;
    for (i = 0; i < command.length; i++)
        argv[i] = command[i].toStringz;
    argv[i] = null;

    // Give the child process the capability to send back dependencies.
    setenv("BRILLIANT_BUILD", "%d\0".format(depsfd).ptr, 1);

    // Redirect stdout/stderr to the pipe the parent reads from
    dup2(stdfd, STDOUT_FILENO);
    dup2(stdfd, STDERR_FILENO);

    execvp(argv[0], argv);

    // If we get this far, something went wrong. Most likely, the command does
    // not exist.
    perror("execvp");
}
