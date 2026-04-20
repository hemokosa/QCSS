# QCSS — Quantum Computing-based Sound Synthesis

**量子計算に基づく音響合成のためのライブコーディング環境**

by Akihiro Kubota

---

## 概要

QCSSは、量子コンピューティングの概念をリアルタイム音響合成に応用するSuperCollider用ライブコーディングフレームワークです。量子ビットの状態ベクトルを加算合成のパラメータに直接マッピングすることで、量子ゲート操作がそのまま音色変化として体験できます。

### 基本原理

```
量子状態ベクトル |ψ⟩ = Σ αᵢ|i⟩
        ↓
各基底状態 |i⟩ → 正弦波オシレータ
  振幅: |αᵢ|
  位相: arg(αᵢ)
  周波数: f₀ × ratio[i]（Gray code順で配置）
```

- **6量子ビット**（デフォルト）= **64基底状態** = **64正弦波**による加算合成
- 量子ゲートで状態ベクトルを操作 → 倍音構成がリアルタイムに変化
- Gray code順に周波数を配置し、隣接する量子状態が近接した周波数に対応

---

## セットアップ

### 必要環境

- [SuperCollider](https://supercollider.github.io/) 3.13以降

### インストール

```
git clone https://github.com/hemokosa/QCSS.git
```

### 起動

SuperCollider IDEで `QCSS.scd` を開き、ファイル全体を評価（`Cmd+Enter` / `Ctrl+Enter`）します。

```supercollider
// 1. ライブラリの読み込み（QCSS.scd を評価）
// → "QCSS loaded." と表示される

// 2. サーバ起動＋発音
~q.boot { |q| q.go(220) };
// → "QCSS ready: 6 qubits, 64 states, scale=exponential" と表示

// 3. 量子ゲートを適用して音色を変化
~q.h(0).cnot(0, 1).sync(440);
```

---

## ファイル構成

```
QCSS/
├── QCSS.scd                  — メインライブラリ
└── examples/
    └── live_examples.scd     — ライブコーディング用サンプル集
```

---

## API リファレンス

全機能は `~q` オブジェクト（SuperCollider Event）に格納されています。ほとんどのメソッドは `self` を返すため、メソッドチェーンが可能です。

> **命名規則について**: SuperCollider の Event クラスには `play`, `stop`, `update`, `set` が既存メソッドとして定義されているため、競合を避けるために以下の別名を使用しています。

### 初期化・制御

| メソッド | 説明 |
|---|---|
| `~q.init(nQubits)` | 量子ビット数を指定して初期化（デフォルト: 6） |
| `~q.resetState` | 状態ベクトルを \|0...0⟩ に戻す |
| `~q.boot { \|q\| ... }` | SynthDef構築 → サーバ起動 → コールバック実行 |
| `~q.go(f0, amp)` | シンセを生成し発音（デフォルト: f0=220, amp=0.2） |
| `~q.hush` | 発音停止 |
| `~q.hush(sec)` | sec秒後にフェードアウト停止 |
| `~q.goFor(f0, sec, amp)` | 指定秒数だけ発音して自動停止 |
| `~q.sync(f0)` | 現在の状態ベクトルをシンセに反映（基準周波数 f0） |
| `~q.ctrl(\param, val, ...)` | シンセパラメータを直接設定 |

### 量子ゲート

全ゲートは状態ベクトルを変換し `self` を返します。チェーン可能です。

#### 単一量子ビットゲート

| メソッド | ゲート | 説明 |
|---|---|---|
| `~q.h(target)` | Hadamard | 重ね合わせを生成。\|0⟩ → (\|0⟩+\|1⟩)/√2 |
| `~q.x(target)` | Pauli-X | ビット反転（NOT）。\|0⟩ ↔ \|1⟩ |
| `~q.y(target)` | Pauli-Y | Y軸回転。\|0⟩ → i\|1⟩, \|1⟩ → −i\|0⟩ |
| `~q.z(target)` | Pauli-Z | 位相反転。\|1⟩ → −\|1⟩ |
| `~q.ss(target)` | S | π/2 位相回転。\|1⟩ → i\|1⟩ |
| `~q.t(target)` | T | π/4 位相回転。\|1⟩ → e^(iπ/4)\|1⟩ |
| `~q.rx(target, theta)` | Rx | X軸まわりの任意角回転 |
| `~q.ry(target, theta)` | Ry | Y軸まわりの任意角回転 |
| `~q.rz(target, theta)` | Rz | Z軸まわりの任意角回転 |

> S ゲートのショートハンドは `~q.ss` です（`~q.s` は SuperCollider のサーバ変数 `s` との混同を避けるため）。レジストリ経由では `~q.applyGate(\s, target)` でも呼び出せます。

#### 多量子ビットゲート

| メソッド | ゲート | 説明 |
|---|---|---|
| `~q.cnot(ctrl, target)` | CNOT | 制御NOT。ctrl=1 のとき target を反転 |
| `~q.cz(ctrl, target)` | CZ | 制御Z。両方 1 のとき位相反転 |
| `~q.swap(q0, q1)` | SWAP | 2量子ビットの状態を入れ替え |
| `~q.toffoli(c0, c1, target)` | Toffoli | 制御制御NOT。c0=c1=1 のとき target を反転 |

#### 汎用ゲート適用

```supercollider
~q.applyGate(\h, 0);             // レジストリ名で呼び出し
~q.applyGate(\rz, 2, pi/3);      // 引数付き
~q.applyGate(\cnot, 0, 1);       // 多量子ビットゲート
```

### 回路記法

ゲート列を配列として定義し、一括適用できます。

```supercollider
~q.circuit([
    [\h, 0],
    [\cnot, 0, 1],
    [\t, 1],
    [\cnot, 1, 2],
    [\h, 2],
]);
```

### 測定

| メソッド | 説明 |
|---|---|
| `~q.prob(target)` | 量子ビットが \|1⟩ になる確率を返す（非破壊） |
| `~q.measure(target)` | 射影測定を行い、0 または 1 を返す（状態ベクトルを射影・正規化） |

```supercollider
// 測定に基づく条件分岐（フィードフォワード）
(
var bit;
bit = ~q.measure(0);
if (bit == 0) { ~q.h(4).t(4) } { ~q.h(5).x(5) };
~q.sync(200);
)
```

### 周波数スケール

量子状態のインデックスを周波数比に変換するスケール（マッピング戦略）を切り替えられます。

#### 内蔵スケール

| 名前 | 説明 | 音色の特徴 |
|---|---|---|
| `\exponential` | 2^(n·i/m)、nオクターブ均等分割 | 密度の高い滑らかなスペクトル（デフォルト） |
| `\golden` | 黄金比に基づく準周期的配置 | 非整数倍音、ベルのような金属的響き |
| `\harmonic` | 整数倍音列 1, 2, 3, ... | 明瞭でブライトなティンバー |
| `\just` | 純正律の12音を繰り返し | 協和的で澄んだ響き |
| `\equal` | 12平均律を繰り返し | 馴染みのある音階的構造 |

```supercollider
~q.setScale(\golden);            // スケール切り替え
~q.setScale(\exponential, 8);    // オクターブ数を変更（デフォルト: 4）
~q.sync(220);                    // 反映
```

#### カスタムスケールの登録

```supercollider
// ピタゴラス音律
~q.registerScale(\pythagorean, { |self, n|
    var m = self.nStates;
    (0 .. (m - 1)).collect { |i|
        (3/2).pow(i % 12) / (2.pow((i % 12 * 7.0 / 12).floor)) * (2 ** i.div(12))
    }
});
~q.setScale(\pythagorean);
```

スケール関数は `|self, nOctaves|` を受け取り、nStates 個の周波数比（Float の配列）を返します。内部でGray code順に自動的に再配置されます。

### カスタムゲートの登録

```supercollider
// 制御Sゲート
~q.registerGate(\cs, { |self, ctrl, tgt|
    var newVec = self.stateVec.copy;
    self.nStates.do { |i|
        if ((self.bitAt(i, ctrl) == 1) and: { self.bitAt(i, tgt) == 1 }) {
            newVec[i] = newVec[i] * Complex(0, 1);
        }
    };
    self.stateVec = newVec;
});

// 使用
~q.applyGate(\cs, 0, 1);
```

ゲート関数は `|self, ...args|` を受け取り、`self.stateVec` を直接書き換えます。

### シーケンサ

Routine ベースの時間進行パターンを実行できます。

```supercollider
// 周波数スイープ
~q.seq { |q|
    30.do { |i|
        q.sync(41 * (i + 1));
        0.5.wait;
    };
};

// ゲートモジュレーション
~q.seq { |q|
    var n = q.nQubits;
    128.do { |i|
        q.h(i % n).t(i % n).x(i % n);
        q.sync(11 * (i + 1));
        0.1.wait;
    };
};

// 停止
~q.hushSeq;
```

### シンセパラメータ

`~q.ctrl` でオーディオエンジンのパラメータを直接制御できます。

| パラメータ | 範囲 | デフォルト | 説明 |
|---|---|---|---|
| `\amp` | 0.0 – 1.0 | 0.2 | マスター音量 |
| `\panRate` | Hz | 0.05 | パンニングLFOの速度 |
| `\panWidth` | 0.0 – 1.0 | 0.9 | パンニングの幅 |
| `\panPhase` | rad | 0.0 | パンニングの位相オフセット |
| `\revMix` | 0.0 – 1.0 | 0.2 | リバーブ Dry/Wet 比 |
| `\revRoom` | 0.0 – 1.0 | 0.8 | リバーブの部屋サイズ |
| `\revDamp` | 0.0 – 1.0 | 0.3 | リバーブの高域減衰 |

```supercollider
~q.ctrl(\panRate, 1.0, \panWidth, 0.9);
~q.ctrl(\revMix, 0.4, \revRoom, 0.9, \revDamp, 0.5);
```

### 状態表示

| メソッド | 説明 |
|---|---|
| `~q.printState` | 状態ベクトルをバイナリインデックス順で表示（振幅 > 0 のみ） |
| `~q.printGray` | 状態ベクトルをGray code順で表示（振幅 > 0 のみ） |

```
// printGray の出力例:
gray[0] [000000] 1.0     0.70711+0i
gray[1] [000001] 1.0443  0.70711+0i
```

---

## オーディオアーキテクチャ

```
状態ベクトル |ψ⟩ (Complex[64])
    │
    ├── |αᵢ|     → amps[64]   ── L2正規化 → RMSゲイン制御
    ├── arg(αᵢ)  → phases[64]
    └── f₀ × gratios[i] → freqs[64]  （Gray code順）
           │
           ▼
┌─────────────────────────────────────────────┐
│  SynthDef \qAdd                             │
│                                             │
│  64× SinOsc.ar(freq, phase) × amp          │
│      → Pan2（個別LFOパン）                  │
│      → Mix                                  │
│      → Compander（セーフティ）              │
│      → Normalizer                           │
│      → EnvGen（ASR エンベロープ）           │
│      → FreeVerb2（ステレオリバーブ）        │
│      → Limiter（最終リミッタ）              │
│                                             │
│  Out.ar → ステレオ出力                      │
└─────────────────────────────────────────────┘
```

3段のセーフティ（Compander → Normalizer → Limiter）により、量子状態がどのように変化しても安全な音量が保証されます。

---

## 設計思想

### 量子状態から音への写像

量子コンピューティングでは、n量子ビット系の状態は 2ⁿ 個の複素振幅で表されます。QCSSではこれを加算合成のパラメータとして直接利用します。

- **重ね合わせ** → 複数の倍音が同時に鳴る（倍音の豊かさ）
- **エンタングルメント** → 倍音間の相関（ゲート操作による構造的な音色変化）
- **位相回転** → 各倍音の位相シフト（音色の微細な変化）
- **測定** → 状態の崩壊（倍音の劇的な減少）

### Gray code による周波数配置

通常のバイナリ順ではなく Gray code 順に周波数を配置しています。Gray code では隣接する番号が1ビットしか異なりません。これにより、量子ゲート（1ビット操作）による状態変化が、周波数的に隣接した倍音間の変化として表現され、聴覚的に滑らかな遷移が得られます。

### 拡張性

QCSSは2つのレジストリパターンを持ちます。

- **ゲートレジストリ** (`registerGate`): 任意の量子ゲートを関数として登録
- **スケールレジストリ** (`registerScale`): 任意の周波数マッピングを登録

これにより、標準的な量子ゲートセットに限定されず、音響的に興味深い独自の操作やスケールを自由に追加できます。

---

## ライブコーディング早見表

```supercollider
// ── 起動 ──
~q.boot { |q| q.go(220) };

// ── ゲート操作（チェーン可能）──
~q.h(0).cnot(0,1).t(1);
~q.sync(440);                     // 音に反映

// ── 回路記法 ──
~q.circuit([[\h,0], [\cnot,0,1], [\t,1]]);

// ── スケール ──
~q.setScale(\golden);
~q.setScale(\exponential, 8);     // 8オクターブ

// ── 測定 ──
~q.prob(0);                       // 確率のみ取得
~q.measure(0);                    // 射影測定（状態崩壊）

// ── 状態リセット ──
~q.resetState;

// ── シーケンス ──
~q.seq { |q| 30.do { |i| q.sync(41*(i+1)); 0.5.wait } };
~q.hushSeq;

// ── パラメータ ──
~q.ctrl(\revMix, 0.4, \revRoom, 0.9);
~q.ctrl(\panRate, 2.0);

// ── 停止 ──
~q.hush;                          // 即停止
~q.hush(3);                       // 3秒フェード
~q.goFor(440, 8, 0.25);          // 8秒間だけ再生

// ── 表示 ──
~q.printState;
~q.printGray;
```

---

## ライセンス

MIT License
