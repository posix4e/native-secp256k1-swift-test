#!/usr/bin/env python3
"""Independent affine Python-integer answers for PUBLIC secp256k1 point tests.

Uses the SEC 2 secp256k1 constants and elementary affine group formulas, not
the Swift implementation or its Jacobian formulas. All scalars are public.
"""
import hashlib
import json
from pathlib import Path

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)


def add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    x1, y1 = a
    x2, y2 = b
    if x1 == x2:
        if (y1 + y2) % P == 0:
            return None
        slope = 3 * x1 * x1 * pow(2 * y1, -1, P) % P
    else:
        slope = (y2 - y1) * pow((x2 - x1) % P, -1, P) % P
    x3 = (slope * slope - x1 - x2) % P
    return x3, (slope * (x1 - x3) - y1) % P


def multiply(point, scalar):
    result = None
    while scalar:
        if scalar & 1:
            result = add(result, point)
        point = add(point, point)
        scalar >>= 1
    return result


def integer(domain, index):
    return int.from_bytes(hashlib.sha256(
        f"winnow-public-point-v1/{domain}/{index}".encode("ascii")).digest(), "big")


def h(value):
    return f"{value:064x}"


def encoded(point):
    return None if point is None else {"x": h(point[0]), "y": h(point[1])}


def main():
    negative = (G[0], P - G[1])
    additions = []
    multiplications = []

    def addition(name, a, b):
        additions.append(dict(name=name, left=encoded(a), right=encoded(b), result=encoded(add(a, b))))

    def multiplication(name, point, scalar):
        multiplications.append(dict(name=name, point=encoded(point), scalar=h(scalar),
                                    result=encoded(multiply(point, scalar))))

    for name, a, b in [("both-infinity", None, None), ("left-infinity", None, G),
                       ("right-infinity", G, None), ("generator-doubled", G, G),
                       ("generator-opposite", G, negative), ("opposite-generator", negative, G),
                       ("negative-doubled", negative, negative)]:
        addition(name, a, b)
    for scalar in [0, 1, 2, 3, 2**32 - 1, 2**128, N - 2, N - 1]:
        multiplication(f"generator-{scalar}", G, scalar)
    multiplication("infinity-zero", None, 0)
    multiplication("infinity-order-minus-one", None, N - 1)
    for i in range(16):
        a = multiply(G, integer("point-a", i) % (N - 1) + 1)
        b = multiply(G, integer("point-b", i) % (N - 1) + 1)
        addition(f"random-{i}", a, b)
        addition(f"random-double-{i}", a, a)
        addition(f"random-opposite-{i}", a, (a[0], P - a[1]))
        multiplication(f"random-{i}", a, integer("scalar", i) % N)
    values = [0, 1, 2, 7, 2**32 - 1, 2**32, 2**128, P - 2, P - 1]
    values += [integer("inverse", i) % P for i in range(16)]
    inverses = [dict(value=h(v), inverse=None if v == 0 else h(pow(v, -1, P))) for v in values]
    # Sanity checks on the independent reference, including the group order.
    assert multiply(G, N) is None
    assert multiply(G, N - 1) == negative
    output = Path(__file__).resolve().parents[1] / "Tests/NativeSecp256k1Tests/Fixtures/public-point-vectors.json"
    output.write_text(json.dumps(dict(additions=additions, multiplications=multiplications,
                                     inverses=inverses), indent=2) + "\n")
    print(json.dumps(dict(additions=len(additions), multiplications=len(multiplications),
                          inverses=len(inverses), sha256=hashlib.sha256(output.read_bytes()).hexdigest()), indent=2))


if __name__ == "__main__":
    main()
