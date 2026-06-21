import sys
from pathlib import Path
import vtracer

def main():
    if len(sys.argv) != 2:
        print("Usage: python vectorize.py <input_image>")
        sys.exit(1)

    inp = Path(sys.argv[1])

    if not inp.exists():
        print(f"Error: file not found -> {inp}")
        sys.exit(1)

    out = inp.with_suffix(".vectorized.svg")

    vtracer.convert_image_to_svg_py(
        str(inp),
        str(out),
        colormode="color",
        hierarchical="stacked",
        mode="spline",
        filter_speckle=4,
        color_precision=6,
        layer_difference=16,
        corner_threshold=60,
        length_threshold=4.0,
        max_iterations=10,
        splice_threshold=45,
        path_precision=3,
    )

    print("Created:", out)
    print("Size bytes:", out.stat().st_size)


if __name__ == "__main__":
    main()