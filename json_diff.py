#!/usr/bin/python3

import json
import sys
from optparse import OptionParser


class BadJSONError(ValueError):
    pass


class Comparator(object):
    def __init__(self, fn1=None, fn2=None, opts=None):
        if opts.exclude:
            self.ignored = opts.exclude
        else:
            self.ignored = ["/sys", "/proc"]
        self.show_new = opts.show_new
        self.old = None
        self.new = None
        if fn1:
            try:
                self.old = json.load(fn1)
            except (TypeError, OverflowError, ValueError) as exc:
                raise BadJSONError("Cannot decode object from JSON.\n%s" % str(exc))
        if fn2:
            try:
                self.new = json.load(fn2)
            except (TypeError, OverflowError, ValueError) as exc:
                raise BadJSONError("Cannot decode object from JSON\n%s" % str(exc))

    def compare(self):
        ret = ""
        files_old = {}
        files_new = {}
        plugins_old = set()
        plugins_new = set()

        for plugin in self.old:
            plugins_old.add(plugin[0])
            for section in plugin[1].keys():
                for file in plugin[1][section]:
                    if not any([file["name"].startswith(x) for x in self.ignored]):
                        filename = file["name"]
                        files_old[filename] = plugin[0] + "/" + section

        for plugin in self.new:
            plugins_new.add(plugin[0])
            for section in plugin[1].keys():
                for file in plugin[1][section]:
                    if not any([file["name"].startswith(x) for x in self.ignored]):
                        filename = file["name"]
                        files_new[filename] = plugin[0] + "/" + section

        old_files = set(files_old)
        new_files = set(files_new)

        plugins_old_only = plugins_old - plugins_new
        if plugins_old_only:
            ret += "plugins only in old:\n"
            for p in plugins_old_only:
                ret += "\t%s\n" % p

        old_only = old_files - new_files
        if old_only:
            ret += "files only in old:\n"
            for f in old_only:
                ret += '\t"%s" in %s\n' % (f, files_old[f])

        if self.show_new:
            plugins_new_only = plugins_new - plugins_old
            if plugins_new_only:
                ret += "plugins only in new:\n"
                for p in plugins_new_only:
                    ret += "\t%s\n" % p

            new_only = new_files - old_files
            if new_only:
                ret += "files only in new:\n"
                for f in new_only:
                    ret += '\t"%s" in %s\n' % (f, files_new[f])

        return ret


def main(argv=None):
    sys_args = argv if argv is not None else sys.argv[:]
    usage = "usage: %prog [options] old.json new.json"
    parser = OptionParser(usage=usage)

    parser.add_option(
        "-x",
        "--exclude",
        action="append",
        dest="exclude",
        metavar="ATTR",
        default=[],
        help="folders recursively ignored when comparing (defaults to /sys and /proc)",
    )
    parser.add_option(
        "-o",
        "--output",
        action="append",
        dest="output",
        metavar="FILE",
        default=[],
        help="name of the output file (default is stdout)",
    )
    parser.add_option(
        "-n",
        "--new",
        action="store_true",
        dest="show_new",
        default=False,
        help="show names only in new json (default is false)",
    )

    (options, args) = parser.parse_args(sys_args[1:])

    if options.output:
        outf = open(options.output[0], "w")
    else:
        outf = sys.stdout

    if len(args) != 2:
        parser.error(
            "Script requires two positional arguments, "
            + "names for old and new JSON file."
        )

    with open(args[0]) as old_file, open(args[1]) as new_file:
        diff = Comparator(old_file, new_file, options)
        out = diff.compare()
        print(out, file=outf)
        outf.close()

    return 0


if __name__ == "__main__":
    main_res = main()
    sys.exit(main_res)
