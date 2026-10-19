#!/usr/bin/env python3
"""Pinned BIP340 full-verification fixtures and deterministic PUBLIC differential cases.

Usage: python3 Tools/schnorr_generate_vectors.py BIPS_CHECKOUT SECP_CHECKOUT ORACLE
The C program signs predictable public test scalars only; no real key is used.
Every decision is independently checked with the pinned BIP340 Python reference.
"""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

BIPS_REVISION = "927b6de9915c9262615a6399de51b200f81e5aa4"
SECP_REVISION = "1a53f4961f337b4d166c25fce72ef0dc88806618"
P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
DOMAIN = "winnow-public-bip340-v1"


def check_revision(path, expected):
    actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    if actual != expected:
        raise RuntimeError(f"revision mismatch: {path}: {actual}")
    if subprocess.check_output(["git", "-C", str(path), "status", "--porcelain", "--untracked-files=no"], text=True):
        raise RuntimeError(f"tracked files modified: {path}")


def h(value):
    return value.to_bytes(32, "big")


def derived(label, index, length=32):
    return hashlib.shake_256(f"{DOMAIN}/{label}/{index}".encode("ascii")).digest(length)


def encoded(value):
    return value.hex() if value else "-"


def run_oracle(path, commands):
    answers = subprocess.check_output([str(path.resolve())], input="\n".join(commands) + "\n", text=True).splitlines()
    if len(answers) != len(commands):
        raise RuntimeError("oracle output count mismatch")
    return answers


def vector(name, key, signature, message, expected, comment=""):
    return dict(name=name, publicKey=key.hex(), signature=signature.hex(), message=message.hex(),
                expected=expected, comment=comment)


def flipped(value, index):
    data = bytearray(value)
    data[index % len(data)] ^= 1 << (index % 8)
    return bytes(data)


def main():
    bips, secp, oracle = map(Path, sys.argv[1:])
    check_revision(bips, BIPS_REVISION)
    check_revision(secp, SECP_REVISION)
    spec = importlib.util.spec_from_file_location("bip340_reference", bips / "bip-0340/reference.py")
    reference = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reference)
    assert reference.p == P and reference.n == N
    official = []
    with (bips / "bip-0340/test-vectors.csv").open(newline="") as source:
        for row in csv.DictReader(source):
            official.append(vector(f"bip340-{row['index']}", bytes.fromhex(row["public key"]),
                                   bytes.fromhex(row["signature"]), bytes.fromhex(row["message"]),
                                   row["verification result"] == "TRUE", row["comment"]))
    assert len(official) == 19
    lengths = [0, 1, 2, 16, 17, 31, 32, 33, 63, 64, 65, 100, 127, 128, 129, 255,
               256, 257, 511, 512, 513, 1024, 2048, 4096, 0, 1, 17, 32, 33, 64, 65, 100]
    commands = []
    inputs = []
    for i, length in enumerate(lengths):
        # Every scalar/auxiliary byte is intentionally public and predictable.
        secret = h(int.from_bytes(derived("public-test-scalar", i), "big") % (N - 1) + 1)
        aux = derived("public-test-aux", i)
        message = derived("message", i, length)
        inputs.append((secret, aux, message))
        commands.append(f"s {secret.hex()} {aux.hex()} {encoded(message)}")
    signed = run_oracle(oracle, commands)
    differential = []
    for i, ((secret, aux, message), answer) in enumerate(zip(inputs, signed)):
        key, signature = map(bytes.fromhex, answer.split())
        # Match the entire C-generated signature with independent Python signing,
        # not merely its verification decision.
        if signature != reference.schnorr_sign(message, secret, aux):
            raise RuntimeError(f"C/Python signature disagreement: {i}")
        differential += [
            vector(f"generated-valid-{i}", key, signature, message, True),
            vector(f"mutated-key-{i}", flipped(key, i), signature, message, False),
            vector(f"mutated-r-{i}", key, flipped(signature, i % 32), message, False),
            vector(f"mutated-s-{i}", key, flipped(signature, 32 + i % 32), message, False),
            vector(f"mutated-message-{i}", key, signature,
                   flipped(message, i) if message else b"\x00", False),
        ]
    key = bytes.fromhex(official[0]["publicKey"])
    signature = bytes.fromhex(official[0]["signature"])
    message = bytes.fromhex(official[0]["message"])
    for label, values, target in [("public-key", [0, P, P + 1, 2**256 - 1], "key"),
                                   ("r", [P, P + 1, 2**256 - 1], "r"),
                                   ("s", [0, N, N + 1, 2**256 - 1], "s")]:
        for i, value in enumerate(values):
            changed_key = h(value) if target == "key" else key
            changed_sig = (h(value) + signature[32:] if target == "r" else
                           signature[:32] + h(value) if target == "s" else signature)
            differential.append(vector(f"boundary-{label}-{i}", changed_key, changed_sig, message, False))
    # Construct exact exceptional verification equations, using only public d=3.
    # Set s=e*d to force sG-eP=infinity for r=0 and r=1.
    d = 3 if reference.has_even_y(reference.point_mul(reference.G, 3)) else N - 3
    for r in [0, 1]:
        challenge = int.from_bytes(reference.tagged_hash("BIP0340/challenge", h(r) + key + message), "big") % N
        infinity_sig = h(r) + h(challenge * d % N)
        differential.append(vector(f"constructed-infinity-r{r}", key, infinity_sig, message, False,
                                   "sG-eP is infinity; infinity is never an acceptable R"))
    # An otherwise matching equation with odd R must still be rejected.
    k = next(k for k in range(1, 100) if not reference.has_even_y(reference.point_mul(reference.G, k)))
    r = reference.point_mul(reference.G, k)[0]
    challenge = int.from_bytes(reference.tagged_hash("BIP0340/challenge", h(r) + key + message), "big") % N
    odd_sig = h(r) + h((k + challenge * d) % N)
    differential.append(vector("constructed-odd-r", key, odd_sig, message, False,
                               "R has matching x but odd y; BIP340 requires even y"))
    # Adapter-length checks are explicit; the C library itself accepts fixed-size
    # arrays, so these are wrapper-contract checks, not C malformed-buffer tests.
    for length in [0, 1, 31, 33, 64]:
        malformed = (key + key)[:length]
        differential.append(vector(f"length-public-key-{length}", malformed, signature, message, False))
    for length in [0, 1, 63, 65, 96]:
        malformed = (signature + signature)[:length]
        differential.append(vector(f"length-signature-{length}", key, malformed, message, False))
    combined = official + differential
    commands = [f"v {encoded(bytes.fromhex(v['publicKey']))} {encoded(bytes.fromhex(v['signature']))} "
                f"{encoded(bytes.fromhex(v['message']))}" for v in combined]
    decisions = run_oracle(oracle, commands)
    for v, answer in zip(combined, decisions):
        key, sig, message = [bytes.fromhex(v[f]) for f in ["publicKey", "signature", "message"]]
        python_result = len(key) == 32 and len(sig) == 64 and reference.schnorr_verify(message, key, sig)
        if answer not in {"0", "1"} or (answer == "1") != v["expected"] or python_result != v["expected"]:
            raise RuntimeError(f"decision disagrees for {v['name']}: C={answer}, Python={python_result}")
    output = Path(__file__).resolve().parents[1] / "Tests/NativeSecp256k1Tests/Fixtures"
    digests = {}
    for name, rows in [("bip340-verification-official", official), ("bip340-verification-differential", differential)]:
        path = output / f"{name}.json"
        path.write_text(json.dumps(rows, indent=2) + "\n")
        digests[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    result = dict(bipsRevision=BIPS_REVISION, secp256k1Revision=SECP_REVISION,
                  officialCases=len(official), differentialCases=len(differential),
                  officialValid=sum(v["expected"] for v in official),
                  differentialValid=sum(v["expected"] for v in differential),
                  messagesBytes=sorted(set(len(bytes.fromhex(v["message"])) for v in combined)),
                  hashes=digests)
    (output / "bip340-verification-provenance.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
