/* Offline PUBLIC-test-data oracle. Never linked into the Swift product.
 * Lines: s <public-test-scalar hex> <aux hex> <message hex or ->
 *        v <x-only public key hex or -> <signature hex or -> <message hex or ->
 * Signing here exists solely to generate independent public test fixtures.
 */
#include <stdio.h>
#include <string.h>
#include "secp256k1.h"
#include "secp256k1_extrakeys.h"
#include "secp256k1_schnorrsig.h"

static int nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

static int decode(const char *text, unsigned char *out, size_t capacity, size_t *length) {
    size_t chars = strcmp(text, "-") == 0 ? 0 : strlen(text);
    if (chars % 2 || chars / 2 > capacity) return 0;
    *length = chars / 2;
    for (size_t i = 0; i < *length; i++) {
        int a = nibble(text[2 * i]), b = nibble(text[2 * i + 1]);
        if (a < 0 || b < 0) return 0;
        out[i] = (unsigned char)((a << 4) | b);
    }
    return 1;
}

static void printhex(const unsigned char *data, size_t length) {
    for (size_t i = 0; i < length; i++) printf("%02x", data[i]);
}

int main(void) {
    char line[32768];
    secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
    while (fgets(line, sizeof(line), stdin)) {
        if (!strchr(line, '\n')) return 2;
        char *mode = strtok(line, " \n");
        char *first = strtok(NULL, " \n");
        char *second = strtok(NULL, " \n");
        char *third = strtok(NULL, " \n");
        if (!mode || !first || !second || !third || strtok(NULL, " \n")) return 3;
        unsigned char a[256], b[256], message[8192];
        size_t alen, blen, mlen;
        if (!decode(first, a, sizeof(a), &alen) || !decode(second, b, sizeof(b), &blen)
            || !decode(third, message, sizeof(message), &mlen)) return 4;
        if (strcmp(mode, "v") == 0) {
            secp256k1_xonly_pubkey key;
            int valid = alen == 32 && blen == 64
                && secp256k1_xonly_pubkey_parse(ctx, &key, a)
                && secp256k1_schnorrsig_verify(ctx, b, message, mlen, &key);
            printf("%d\n", valid);
        } else if (strcmp(mode, "s") == 0) {
            if (alen != 32 || blen != 32) return 5;
            secp256k1_keypair pair;
            secp256k1_xonly_pubkey key;
            unsigned char signature[64], public_key[32];
            secp256k1_schnorrsig_extraparams extra = SECP256K1_SCHNORRSIG_EXTRAPARAMS_INIT;
            extra.ndata = b;
            if (!secp256k1_keypair_create(ctx, &pair, a)
                || !secp256k1_keypair_xonly_pub(ctx, &key, NULL, &pair)
                || !secp256k1_xonly_pubkey_serialize(ctx, public_key, &key)
                || !secp256k1_schnorrsig_sign_custom(ctx, signature, message, mlen, &pair, &extra)
                || !secp256k1_schnorrsig_verify(ctx, signature, message, mlen, &key)) return 6;
            printhex(public_key, 32);
            putchar(' ');
            printhex(signature, 64);
            putchar('\n');
        } else {
            return 7;
        }
    }
    secp256k1_context_destroy(ctx);
    return ferror(stdin) ? 8 : 0;
}
