#!python3

from importlib.machinery import SourceFileLoader
from argparse import ArgumentParser
from zlax.muflib import init, step
import os, subprocess
from sys import stderr
from jax.numpy import ndarray


def main():
    parser = ArgumentParser(description="zluciole")
    parser.add_argument("file")
    parser.add_argument("-prob", action="store_true", help="Simulate ProbZelus code")
    parser.add_argument("-q", dest="quiet", action="store_true", help="Quiet mode")
    parser.add_argument("-no-rebuild", action="store_true", help="Do not rebuild")
    parser.add_argument(
        "-n",
        dest="steps",
        type=int,
        help="Number of steps (default never stops)",
        default=-1,
    )
    parser.add_argument(
        "-s",
        dest="node",
        action="store",
        type=str,
        help="Node to simulate (required)",
        required=True,
    )
    args = parser.parse_args()


    if not args.no_rebuild:
        zlc = "zeluc" if not args.prob else "probzeluc"

        # Compile to Python
        cmd = f"{zlc} -jax {args.file}"

        try:
            subprocess.check_call(cmd, shell=True)
        except subprocess.CalledProcessError as e:
            print("Error :", e, file=stderr)
            exit(-1)

    # Import the node to simulate from the previously compiled Python file
    pyfile = os.path.splitext(args.file)[0] + ".py"
    module = SourceFileLoader("jax_module", pyfile).load_module()
    s = init(getattr(module, args.node))

    def unbox(x):
        if isinstance(x, ndarray):
            return x.tolist()
        return x

    def map_tuple(f, x):
        if isinstance(x, tuple):
            return tuple(map_tuple(f, i) for i in x)
        else:
            return f(x)

    # Simulation loop
    i = 0
    while i < args.steps:
        s, o = step(s, ())
        if not args.quiet:
            print(f"{map_tuple(unbox, o)}")
        if i != -1:
            i += 1


if __name__ == "__main__":
    main()
