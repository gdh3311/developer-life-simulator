"""Generates the in-game company repository content in Korean and English.

    python tools/gen_content.py

Writes content/commerce-api/<lang>/... and content/ci/<lang>/... (hidden CI tests).
Code is identical across languages; comments, docs and test names are localized.
"""
import os
import shutil
from gen_chapter2_content import files as chapter2_files

ROOT = os.path.join(os.path.dirname(__file__), "..", "content")

T = {
    # ---------------------------------------------------------------- base repo
    "readme": {
        "ko": """# commerce-api

NEXORA Commerse Cloud 백엔드 서비스.

## 시작하기

```
npm test        # 테스트 실행
```

## 규칙
- `main`에 직접 push 하지 않는다. 브랜치를 만들고 PR로 병합한다.
- 버그 수정에는 회귀 테스트를 포함한다.
""",
        "en": """# commerce-api

NEXORA Commerse Cloud backend service.

## Getting started

```
npm test        # run the tests
```

## Rules
- Never push to `main` directly. Create a branch and merge through a PR.
- Bug fixes must include a regression test.
""",
    },
    "display_doc": {"ko": "프로필 화면에 표시할 사용자 이름을 만든다.\n * 규칙: Company Wiki > \"사용자 이름 표시 규칙\"",
                    "en": "Builds the user name shown on the profile screen.\n * Rules: Company Wiki > \"Display name rules\""},
    "coupon_doc": {"ko": "주문 금액에 쿠폰을 적용한 결제 금액을 반환한다.\n * 정책: Company Wiki > \"쿠폰 정책\"",
                   "en": "Returns the amount to charge after applying a coupon.\n * Policy: Company Wiki > \"Coupon policy\""},
    "shipping_doc": {"ko": "상품 합계(subtotal)에 대한 배송비를 계산한다.\n * 정책: Company Wiki > \"배송비 정책\"",
                     "en": "Calculates the shipping fee for a subtotal.\n * Policy: Company Wiki > \"Shipping policy\""},
    "shipping_todo": {"ko": "// TODO(#004): 배송비 정책 구현", "en": "// TODO(#004): implement the shipping policy"},
    "subtotal_doc": {"ko": "상품 금액 합계", "en": "Sum of item prices"},
    "total_doc": {"ko": "결제할 주문 금액 (원 단위 반올림)", "en": "Order amount to charge (rounded to whole won)"},
    "ai_comment": {"ko": "// AICode: 인증 요청에 타임아웃을 추가했습니다.", "en": "// AICode: added a timeout to the authentication request."},
    "ai_test_comment": {"ko": "// AICode: 기본 동작 테스트", "en": "// AICode: basic behaviour test"},
    "percent_comment": {"ko": "value: 0~100 (%)", "en": "value: 0-100 (%)"},
    "amount_comment": {"ko": "value: 원", "en": "value: won"},
    # test names
    "t_order_total": {"ko": "주문 합계를 계산한다", "en": "calculates the order total"},
    "t_join": {"ko": "이름과 성을 공백 하나로 연결한다", "en": "joins first and last name with one space"},
    "t_trim": {"ko": "앞뒤 공백을 제거한다", "en": "trims surrounding whitespace"},
    "t_first_only": {"ko": "성이 없으면 이름만 표시한다", "en": "shows only the first name when there is no last name"},
    "t_last_only": {"ko": "이름이 없으면 성만 표시한다", "en": "shows only the last name when there is no first name"},
    "t_unknown": {"ko": "둘 다 비어 있으면 Unknown User를 표시한다", "en": "shows Unknown User when both are empty"},
    "t_nick": {"ko": "닉네임이 있으면 닉네임을 표시한다", "en": "shows the nickname when there is one"},
    "t_amount": {"ko": "정액 쿠폰을 적용한다", "en": "applies an amount coupon"},
    "t_percent": {"ko": "정률 쿠폰은 퍼센트로 계산한다", "en": "percent coupons use a percentage"},
    "t_floor0": {"ko": "결제 금액은 0원 미만이 될 수 없다", "en": "the charge never goes below zero"},
    "t_free": {"ko": "5만원 이상이면 무료 배송", "en": "free shipping from 50,000 won"},
    "t_session": {"ko": "토큰을 받으면 세션을 만든다", "en": "creates a session when a token is returned"},
    # hidden CI tests
    "c_tab": {"ko": "[CI] 탭과 줄바꿈도 공백으로 보고 제거한다", "en": "[CI] treats tabs and newlines as whitespace"},
    "c_empty": {"ko": "[CI] 빈 문자열 이름은 없는 것으로 본다", "en": "[CI] an empty string counts as missing"},
    "c_nulls": {"ko": "[CI] 둘 다 null 이면 Unknown User", "en": "[CI] both null gives Unknown User"},
    "c_nick_keep": {"ko": "[CI] 닉네임 기능이 유지된다", "en": "[CI] the nickname feature still works"},
    "c_nick_trim": {"ko": "[CI] 닉네임 앞뒤 공백은 제거한다", "en": "[CI] nickname whitespace is trimmed"},
    "c_nick_blank": {"ko": "[CI] 공백뿐인 닉네임은 무시하고 이름 규칙을 따른다", "en": "[CI] a blank nickname falls back to the name rules"},
    "c_nick_none": {"ko": "[CI] 닉네임이 없으면 기존 이름 규칙 (#001)", "en": "[CI] without a nickname the #001 rules apply"},
    "c_ship_50k": {"ko": "[CI] 정확히 50,000원이면 무료 배송", "en": "[CI] exactly 50,000 won ships free"},
    "c_ship_49": {"ko": "[CI] 49,999원이면 기본 배송비 3,000원", "en": "[CI] 49,999 won pays the 3,000 won base fee"},
    "c_ship_remote": {"ko": "[CI] 도서산간은 무료 배송이어도 5,000원 추가", "en": "[CI] remote areas always add 5,000 won"},
    "c_ship_zero": {"ko": "[CI] 빈 주문(0원)은 배송비 없음", "en": "[CI] an empty order (0 won) has no fee"},
    "c_total_ship": {"ko": "[CI] orderTotal 은 배송비를 포함한다", "en": "[CI] orderTotal includes shipping"},
    "c_subtotal": {"ko": "[CI] main의 subtotal() 리팩터링이 유지된다", "en": "[CI] the subtotal() refactor from main is kept"},
    "c_subtotal_msg": {"ko": "main에 있는 subtotal()이 이 브랜치에 없습니다. main을 병합하세요.", "en": "subtotal() from main is missing on this branch. Merge main into it."},
    "c_timeout": {"ko": "[CI] 응답이 없으면 AUTH_TIMEOUT", "en": "[CI] no response gives AUTH_TIMEOUT"},
    "c_failed": {"ko": "[CI] 토큰이 없으면 AUTH_FAILED (타임아웃과 구분)", "en": "[CI] no token gives AUTH_FAILED (not a timeout)"},
    "c_passthru": {"ko": "[CI] 인증 서버 에러는 그대로 전달한다", "en": "[CI] identity provider errors pass through"},
    "c_ok_login": {"ko": "[CI] 정상 로그인", "en": "[CI] successful login"},
    "c_floor": {"ko": "[CI] 정률 쿠폰 원 단위 이하는 버린다", "en": "[CI] percent discounts round down to whole won"},
}


def files(lang):
    t = {k: v[lang] for k, v in T.items()}
    hdr = "import { test } from 'node:test';\nimport assert from 'node:assert/strict';\n"
    f = {}
    # ---- base
    f["commerce-api/base/README.md"] = t["readme"]
    f["commerce-api/base/gitignore.txt"] = "node_modules/\n*.log\n"
    f["commerce-api/base/package.json"] = """{
  "name": "commerce-api",
  "version": "0.14.2",
  "private": true,
  "type": "module",
  "description": "NEXORA Commerce Cloud backend",
  "scripts": {
    "test": "node --experimental-strip-types --test tests/"
  }
}
"""
    f["commerce-api/base/src/auth/login.ts"] = """export type Session = { userId: string; token: string; expiresAt: number };

export async function login(
  authenticate: () => Promise<string | null>,
  userId: string,
): Promise<Session> {
  const token = await authenticate();
  if (!token) {
    throw new Error('AUTH_FAILED');
  }
  return { userId, token, expiresAt: Date.now() + 60 * 60 * 1000 };
}
"""
    f["commerce-api/base/src/orders/orders.ts"] = """export type OrderItem = { sku: string; price: number; quantity: number };

export function orderTotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
"""
    f["commerce-api/base/src/payments/payments.ts"] = """export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'refunded';

export function canRefund(status: PaymentStatus): boolean {
  return status === 'paid';
}
"""
    f["commerce-api/base/src/users/displayName.ts"] = """export type User = {
  firstName?: string | null;
  lastName?: string | null;
};

/**
 * %s
 */
export function getDisplayName(user: User): string {
  return `${user.firstName} ${user.lastName}`;
}
""" % t["display_doc"]
    f["commerce-api/base/tests/orders.test.ts"] = hdr + """import { orderTotal } from '../src/orders/orders.ts';

test('%s', () => {
  assert.equal(orderTotal([{ sku: 'A', price: 1000, quantity: 2 }, { sku: 'B', price: 500, quantity: 1 }]), 2500);
});
""" % t["t_order_total"]
    # ---- m02: Mina's reproduction tests
    f["commerce-api/m02/displayName.test.ts"] = hdr + """import { getDisplayName } from '../src/users/displayName.ts';

test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi' }), 'Mina Choi');
});

test('%s', () => {
  assert.equal(getDisplayName({ firstName: '  Mina ', lastName: ' Choi  ' }), 'Mina Choi');
});

test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null }), 'Mina');
});

test('%s', () => {
  assert.equal(getDisplayName({ lastName: 'Choi' }), 'Choi');
});

test('%s', () => {
  assert.equal(getDisplayName({ firstName: '   ', lastName: undefined }), 'Unknown User');
});
""" % (t["t_join"], t["t_trim"], t["t_first_only"], t["t_last_only"], t["t_unknown"])
    # ---- m04: Sophie's nickname change (regresses #001)
    f["commerce-api/m04/displayName.ts"] = """export type User = {
  firstName?: string | null;
  lastName?: string | null;
  nickname?: string | null;
};

/**
 * %s
 */
export function getDisplayName(user: User): string {
  if (user.nickname) {
    return user.nickname;
  }
  return `${user.firstName} ${user.lastName}`;
}
""" % t["display_doc"]
    f["commerce-api/m04/nickname.test.ts"] = hdr + """import { getDisplayName } from '../src/users/displayName.ts';

test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
""" % t["t_nick"]
    # ---- m05: coupon PR
    coupon_type = """export type Coupon =
  | { type: 'percent'; value: number }  // %s
  | { type: 'amount'; value: number };  // %s

/**
 * %s
 */
""" % (t["percent_comment"], t["amount_comment"], t["coupon_doc"])
    f["commerce-api/m05/coupon.ts"] = coupon_type + """export function applyCoupon(total: number, coupon: Coupon): number {
  if (coupon.type === 'percent') {
    return total - total * coupon.value;
  }
  return total - coupon.value;
}
"""
    f["commerce-api/m05/coupon_fixed.ts"] = coupon_type + """export function applyCoupon(total: number, coupon: Coupon): number {
  const discount = coupon.type === 'percent'
    ? Math.floor(total * (coupon.value / 100))
    : coupon.value;
  return Math.max(0, total - discount);
}
"""
    f["commerce-api/m05/coupon.test.ts"] = hdr + """import { applyCoupon } from '../src/orders/coupon.ts';

test('%s', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});
""" % t["t_amount"]
    coupon_tests = hdr + """import { applyCoupon } from '../src/orders/coupon.ts';

test('%s%s', () => {
  assert.equal(applyCoupon(10000, { type: 'amount', value: 3000 }), 7000);
});

test('%s%s', () => {
  assert.equal(applyCoupon(10000, { type: 'percent', value: 10 }), 9000);
});

test('%s%s', () => {
  assert.equal(applyCoupon(2000, { type: 'amount', value: 5000 }), 0);
});
"""
    f["commerce-api/m05/coupon_fixed.test.ts"] = coupon_tests % ("", t["t_amount"], "", t["t_percent"], "", t["t_floor0"])
    f["ci/m08/ci_coupon.test.ts"] = coupon_tests % ("[CI] ", t["t_amount"], "[CI] ", t["t_percent"], "[CI] ", t["t_floor0"]) + """
test('%s', () => {
  assert.equal(applyCoupon(9999, { type: 'percent', value: 15 }), 8500);
});
""" % t["c_floor"]
    # ---- m06: shipping
    f["commerce-api/m06/shipping.ts"] = """export type Region = 'normal' | 'remote';

/**
 * %s
 */
export function shippingFee(subtotal: number, region: Region = 'normal'): number {
  %s
  throw new Error('Not implemented');
}
""" % (t["shipping_doc"], t["shipping_todo"])
    f["commerce-api/m06/shipping.test.ts"] = hdr + """import { shippingFee } from '../src/orders/shipping.ts';

test('%s', () => {
  assert.equal(shippingFee(60000), 0);
});
""" % t["t_free"]
    f["commerce-api/m06/orders_refactor.ts"] = """export type OrderItem = { sku: string; price: number; quantity: number };

/** %s */
export function subtotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

/** %s */
export function orderTotal(items: OrderItem[]): number {
  return Math.round(subtotal(items));
}
""" % (t["subtotal_doc"], t["total_doc"])
    # ---- m07: AI patch (subtle bug: every error becomes AUTH_TIMEOUT)
    f["commerce-api/m07/ai_login.ts"] = """export type Session = { userId: string; token: string; expiresAt: number };

%s
export async function login(
  authenticate: () => Promise<string | null>,
  userId: string,
  timeoutMs = 5000,
): Promise<Session> {
  try {
    const token = await Promise.race([
      authenticate(),
      new Promise<null>((_, reject) => setTimeout(() => reject(new Error('timeout')), timeoutMs)),
    ]);
    if (!token) {
      throw new Error('AUTH_FAILED');
    }
    return { userId, token, expiresAt: Date.now() + 60 * 60 * 1000 };
  } catch {
    throw new Error('AUTH_TIMEOUT');
  }
}
""" % t["ai_comment"]
    f["commerce-api/m07/ai_login.test.ts"] = hdr + """import { login } from '../src/auth/login.ts';

%s
test('%s', async () => {
  const session = await login(async () => 'token-123', 'u1', 50);
  assert.equal(session.token, 'token-123');
});
""" % (t["ai_test_comment"], t["t_session"])
    # ---- hidden CI tests
    f["ci/m02/ci_displayName.test.ts"] = hdr + """import { getDisplayName } from '../src/users/displayName.ts';

test('%s', () => {
  assert.equal(getDisplayName({ firstName: '\\tMina\\n', lastName: ' Choi' }), 'Mina Choi');
});
test('%s', () => {
  assert.equal(getDisplayName({ firstName: '', lastName: 'Choi' }), 'Choi');
});
test('%s', () => {
  assert.equal(getDisplayName({ firstName: null, lastName: null }), 'Unknown User');
});
""" % (t["c_tab"], t["c_empty"], t["c_nulls"])
    f["ci/m04/ci_nickname.test.ts"] = hdr + """import { getDisplayName } from '../src/users/displayName.ts';

test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Sophie', lastName: 'Lee', nickname: 'soso' }), 'soso');
});
test('%s', () => {
  assert.equal(getDisplayName({ nickname: '  soso ' }), 'soso');
});
test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: 'Choi', nickname: '   ' }), 'Mina Choi');
});
test('%s', () => {
  assert.equal(getDisplayName({ firstName: 'Mina', lastName: null, nickname: null }), 'Mina');
  assert.equal(getDisplayName({}), 'Unknown User');
});
""" % (t["c_nick_keep"], t["c_nick_trim"], t["c_nick_blank"], t["c_nick_none"])
    f["ci/m06/ci_shipping.test.ts"] = hdr + """import { shippingFee } from '../src/orders/shipping.ts';
import * as orders from '../src/orders/orders.ts';

const items = (price: number) => [{ sku: 'A', price, quantity: 1 }];

test('%s', () => {
  assert.equal(shippingFee(50000), 0);
});
test('%s', () => {
  assert.equal(shippingFee(49999), 3000);
});
test('%s', () => {
  assert.equal(shippingFee(60000, 'remote'), 5000);
  assert.equal(shippingFee(10000, 'remote'), 8000);
});
test('%s', () => {
  assert.equal(shippingFee(0), 0);
});
test('%s', () => {
  assert.equal(orders.orderTotal(items(2500)), 5500);
  assert.equal(orders.orderTotal(items(60000)), 60000);
  // @ts-ignore region parameter
  assert.equal(orders.orderTotal(items(10000), 'remote'), 18000);
});
test('%s', () => {
  // @ts-ignore may not exist on an outdated branch
  const subtotal = orders.subtotal;
  assert.equal(typeof subtotal, 'function', '%s');
  assert.equal(subtotal(items(1234)), 1234);
});
""" % (t["c_ship_50k"], t["c_ship_49"], t["c_ship_remote"], t["c_ship_zero"], t["c_total_ship"], t["c_subtotal"], t["c_subtotal_msg"])
    f["ci/m07/ci_login.test.ts"] = hdr + """import { login } from '../src/auth/login.ts';

test('%s', async () => {
  await assert.rejects(login(() => new Promise(() => {}), 'u1', 30), { message: 'AUTH_TIMEOUT' });
});
test('%s', async () => {
  await assert.rejects(login(async () => null, 'u1', 30), { message: 'AUTH_FAILED' });
});
test('%s', async () => {
  await assert.rejects(login(async () => { throw new Error('IDP_DOWN'); }, 'u1', 30), { message: 'IDP_DOWN' });
});
test('%s', async () => {
  const s = await login(async () => 'tok', 'u9', 30);
  assert.equal(s.userId, 'u9');
  assert.equal(s.token, 'tok');
});
""" % (t["c_timeout"], t["c_failed"], t["c_passthru"], t["c_ok_login"])
    f.update(chapter2_files(lang))
    return f


def main():
    for d in ("commerce-api", "ci"):
        shutil.rmtree(os.path.join(ROOT, d), ignore_errors=True)
    n = 0
    for lang in ("ko", "en"):
        for rel, text in files(lang).items():
            top, rest = rel.split("/", 1)
            p = os.path.join(ROOT, top, lang, rest)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
            n += 1
    print(n, "files written")


if __name__ == "__main__":
    main()
