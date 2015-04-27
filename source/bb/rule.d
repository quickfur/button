/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Parses rules.
 */
module bb.rule;

import io.stream.types : isSource;

struct Rule
{
    string[] inputs, outputs;
    immutable(string)[] task;
}

struct Rules
{
    import std.json : JSONValue;

    private
    {
        JSONValue[] rules;

        // Current rule taken from the stream.
        Rule rule;

        bool _empty;
    }

    this(JSONValue rules)
    {
        this.rules = rules.array();

        // Prime the cannon
        popFront();
    }

    void popFront()
    {
        import std.range : empty, popFront, front;
        import std.algorithm : map;
        import std.array : array;
        import std.json : JSONException;

        if (rules.empty)
        {
            _empty = true;
            return;
        }

        auto jsonRule = rules.front;

        // TODO: Normalize input and output paths
        auto inputs = jsonRule["inputs"].array().map!(x => x.str()).array();
        auto outputs = jsonRule["outputs"].array().map!(x => x.str()).array();
        auto task = jsonRule["task"].array().map!(x => x.str()).array().idup;

        rule = Rule(inputs, outputs, task);

        rules.popFront();
    }

    inout(Rule) front() inout
    {
        return rule;
    }

    bool empty() const pure nothrow
    {
        return _empty;
    }
}

/**
 * Convenience function for constructing a Rules range.
 */
Rules parseRules(Stream)(Stream stream)
    if (isSource!Stream)
{
    import std.json : parseJSON;
    import io.range : byBlock;
    return Rules(stream.byBlock!char.parseJSON()["rules"]);
}

/// Ditto
Rules parseRules(string fileName)
{
    import io.file;
    return parseRules(File(fileName, FileFlags.readExisting));
}
