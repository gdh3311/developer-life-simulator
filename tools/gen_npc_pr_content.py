#!/usr/bin/env python3
"""Teammate PR content (scripts/services/npc_pr.gd): buggy, fixed, wrong-fix and learned versions plus hidden CI checks.
Usage: python tools/gen_npc_pr_content.py . [scratch_dir_to_self_check]"""
import os, sys
ROOT = sys.argv[1]

TEST_HEAD = "import { test } from 'node:test';\nimport assert from 'node:assert/strict';\n"


def fee(lang, line, note=""):
    head = {
        "ko": "// 배송비: 기본 3,000원(2kg까지). 2kg을 넘으면 1kg마다 500원.\n// 정책(위키 '배송비'): 1kg에 못 미치는 무게도 1kg으로 계산합니다.\n",
        "en": "// Shipping fee: 3,000 won base (up to 2 kg), then 500 won per extra kg.\n// Policy (Wiki 'Shipping fees'): a partial kg counts as a whole kg.\n",
    }[lang]
    return head + "export function shippingFee(weightKg: number): number {\n" + note + "  const extra = " + line + ";\n  return 3000 + extra * 500;\n}\n"


def boxes(lang, line, note=""):
    head = {
        "ko": "// 포장 상자 수: 상자 하나에 상품 6개까지 담습니다. 남는 상품도 상자가 하나 더 필요합니다.\n",
        "en": "// Boxes to pack: up to 6 items per box. Leftover items need one more box.\n",
    }[lang]
    return head + note + "export function boxCount(items: number): number {\n  return " + line + ";\n}\n"


def tests(imp, cases):
    out = TEST_HEAD + imp
    for name, body in cases:
        out += "\ntest('%s', () => {\n%s});\n" % (name, "".join("  " + b + "\n" for b in body))
    return out


FEE_IMP = "import { shippingFee } from '../src/shipping/fee.ts';\n"
BOX_IMP = "import { boxCount } from '../src/shipping/boxes.ts';\n"
T = {
    "ko": {
        "fee_note": "  // 모자란 무게는 올림, 2kg 이하는 추가 요금 없음\n",
        "box_note": "// 배송비 PR 때처럼 남는 몫은 올림입니다. 7개, 0개도 테스트에 넣었어요.\n",
        "fee_t": [("2kg까지는 기본 배송비", ["assert.equal(shippingFee(2), 3000);"]), ("4kg은 1,000원 추가", ["assert.equal(shippingFee(4), 4000);"])],
        "box_t": [("6개는 상자 하나", ["assert.equal(boxCount(6), 1);"]), ("12개는 상자 두 개", ["assert.equal(boxCount(12), 2);"])],
        "box_lt": [("6개는 상자 하나", ["assert.equal(boxCount(6), 1);"]), ("7개는 상자 두 개 (남는 상품도 상자 필요)", ["assert.equal(boxCount(7), 2);"]), ("0개는 상자 없음", ["assert.equal(boxCount(0), 0);"])],
        "fee_ci": [("[CI] 2.3kg은 3kg으로 계산 (모자란 무게 올림)", ["assert.equal(shippingFee(2.3), 3500);"]), ("[CI] 1kg 주문도 기본 배송비 (음수 추가 요금 없음)", ["assert.equal(shippingFee(1), 3000);"])],
        "box_ci": [("[CI] 7개는 상자 두 개", ["assert.equal(boxCount(7), 2);"]), ("[CI] 1개도 상자 하나, 0개는 없음", ["assert.equal(boxCount(1), 1);", "assert.equal(boxCount(0), 0);"])],
    },
    "en": {
        "fee_note": "  // round partial kg up; nothing extra at 2 kg or less\n",
        "box_note": "// Like the shipping fee PR, leftovers round up. Tests cover 7 and 0 items.\n",
        "fee_t": [("base fee up to 2 kg", ["assert.equal(shippingFee(2), 3000);"]), ("4 kg adds 1,000 won", ["assert.equal(shippingFee(4), 4000);"])],
        "box_t": [("6 items fit one box", ["assert.equal(boxCount(6), 1);"]), ("12 items need two boxes", ["assert.equal(boxCount(12), 2);"])],
        "box_lt": [("6 items fit one box", ["assert.equal(boxCount(6), 1);"]), ("7 items need two boxes (leftovers need a box)", ["assert.equal(boxCount(7), 2);"]), ("0 items need no box", ["assert.equal(boxCount(0), 0);"])],
        "fee_ci": [("[CI] 2.3 kg is charged as 3 kg (partial kg rounds up)", ["assert.equal(shippingFee(2.3), 3500);"]), ("[CI] a 1 kg order pays the base fee (no negative extra)", ["assert.equal(shippingFee(1), 3000);"])],
        "box_ci": [("[CI] 7 items need two boxes", ["assert.equal(boxCount(7), 2);"]), ("[CI] 1 item needs a box, 0 items none", ["assert.equal(boxCount(1), 1);", "assert.equal(boxCount(0), 0);"])],
    },
}


def write(path, text):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


for lang, t in T.items():
    n = "content/commerce-api/%s/npc/" % lang
    write(n + "jw_shipping/fee.ts", fee(lang, "Math.round(weightKg - 2)"))
    write(n + "jw_shipping/fee_fixed.ts", fee(lang, "Math.max(0, Math.ceil(weightKg - 2))", t["fee_note"]))
    write(n + "jw_shipping/fee_wrong.ts", fee(lang, "Math.max(0, Math.round(weightKg - 2))"))
    write(n + "jw_shipping/fee.test.ts", tests(FEE_IMP, t["fee_t"]))
    write(n + "jw_boxes/boxes.ts", boxes(lang, "Math.round(items / 6)"))
    write(n + "jw_boxes/boxes_learned.ts", boxes(lang, "Math.ceil(items / 6)", t["box_note"]))
    write(n + "jw_boxes/boxes_fixed.ts", boxes(lang, "Math.ceil(items / 6)"))
    write(n + "jw_boxes/boxes_wrong.ts", boxes(lang, "Math.floor(items / 6) + 1"))
    write(n + "jw_boxes/boxes.test.ts", tests(BOX_IMP, t["box_t"]))
    write(n + "jw_boxes/boxes_learned.test.ts", tests(BOX_IMP, t["box_lt"]))
    c = "content/ci/%s/" % lang
    write(c + "npc_jw_shipping/ci_fee.test.ts", tests(FEE_IMP, t["fee_ci"]))
    write(c + "npc_jw_boxes/ci_boxes.test.ts", tests(BOX_IMP, t["box_ci"]))

# Self-check: run every variant against the public + hidden tests in a scratch repo.
if len(sys.argv) > 2:
    import subprocess, shutil
    work = sys.argv[2]
    expect = {("jw_shipping", "fee"): False, ("jw_shipping", "fee_fixed"): True, ("jw_shipping", "fee_wrong"): False,
              ("jw_boxes", "boxes"): False, ("jw_boxes", "boxes_learned"): True, ("jw_boxes", "boxes_fixed"): True, ("jw_boxes", "boxes_wrong"): False}
    ok_all = True
    for lang in T:
        for (spec, var), want in expect.items():
            d = os.path.join(work, lang, spec, var)
            os.makedirs(os.path.join(d, "src", "shipping"), exist_ok=True)
            os.makedirs(os.path.join(d, "tests"), exist_ok=True)
            mod = "fee" if spec == "jw_shipping" else "boxes"
            n = os.path.join(ROOT, "content/commerce-api", lang, "npc", spec)
            shutil.copy(os.path.join(n, var + ".ts"), os.path.join(d, "src", "shipping", mod + ".ts"))
            pub = mod + ("_learned" if var == "boxes_learned" else "") + ".test.ts"
            shutil.copy(os.path.join(n, pub), os.path.join(d, "tests", mod + ".test.ts"))
            for h in os.listdir(os.path.join(ROOT, "content/ci", lang, "npc_" + spec)):
                shutil.copy(os.path.join(ROOT, "content/ci", lang, "npc_" + spec, h), os.path.join(d, "tests", h))
            r = subprocess.run(["node", "--experimental-strip-types", "--test"] + ["tests/" + x for x in os.listdir(os.path.join(d, "tests"))], cwd=d, capture_output=True, text=True, encoding="utf-8")
            pub_r = subprocess.run(["node", "--experimental-strip-types", "--test", "tests/" + mod + ".test.ts"], cwd=d, capture_output=True, text=True, encoding="utf-8")
            got = r.returncode == 0
            print(lang, spec, var, "hidden+public pass" if got else "fails with hidden", "| public", "pass" if pub_r.returncode == 0 else "FAIL")
            ok_all &= got == want and pub_r.returncode == 0 or (var in ("fee_wrong", "boxes_wrong") and got == want)
    print("ALL AS EXPECTED" if ok_all else "MISMATCH")
