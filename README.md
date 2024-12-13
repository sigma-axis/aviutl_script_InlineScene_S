# InlineScene_S AviUtl スクリプト

別シーンに切り替えなくても，シーンのように複数オブジェクトを1枚の画像に集約して扱えるようになるスクリプト．

集約した画像は名前を付けて管理していて，他のスクリプトからも利用可能．画像2つ以上を組み合わせるフィルタ効果の作成もできます．

[ダウンロードはこちら．](https://github.com/sigma-axis/aviutl_script_InlineScene_S/releases)

![図形を複数まとめる動作デモ](https://github.com/user-attachments/assets/8c968434-1074-4b4c-bbf3-8561df6f35a2)

## 動作要件

- AviUtl 1.10 (1.00 など他バージョンでは動作不可)

  http://spring-fragrance.mints.ne.jp/aviutl

  - 加えて環境設定で，「キャッシュメモリ」の項目が十分な大きさだけ必要です．

- 拡張編集 0.92

  - 0.93rc1 など他バージョンでは動作不可．

- patch.aul (謎さうなフォーク版)

  https://github.com/nazonoSAUNA/patch.aul

  - `patch.aul.json` にて以下の設定が必要です (デフォルト値のままなのでほとんどの場合変更する必要はありません):
    1.  `"switch"` 以下の `"lua"` と `"lua.getvalue"` を `true` に．
    1.  `"switch"` 以下の `"shared_cache"` を `true` に．

- [LuaJIT](https://luajit.org/)

  バイナリのダウンロードは[こちら](https://github.com/Per-Terra/LuaJIT-Auto-Builds/releases)からできます．

  - 拡張編集 0.93rc1 同梱の `lua51jit.dll` は***バージョンが古く既知のバグもあるため非推奨***です．
  - AviUtl のフォルダにある `lua51.dll` と置き換えてください．

## 導入方法

以下のフォルダのいずれかに `@InlineScene_S.anm`, `@InlineScene_S.obj`, `InlineScene_S.lua` の 3 つのファイルをコピーしてください．

1. `exedit.auf` のあるフォルダにある `script` フォルダ
1. (1) のフォルダにある任意の名前のフォルダ

## 仕組み

[`Inline Sceneここから`](#inline-sceneここから) が処理されると，現在のフレーム画像やアルファ値のあり/なしの状態を読み取ってバックアップとして保存します．次に現在のフレームバッファをクリアしてアルファ値のあり/なしの状態を上書きします．こうすることで次以降のレイヤーでは，*あたかも*新規シーンで処理されたかのように画像データがフレームバッファに描画されていくようになります．

[`Inline Sceneここまで`](#inline-sceneここまで) が処理されると，`Inline Sceneここから` でバックアップされていたフレーム画像とアルファ値のあり/なしの状態を復元，今あるフレーム画像を現在のオブジェクトの画像として利用します．こうすることで `Inline Sceneここから` と `Inline Sceneここまで` の間にあるレイヤー上のオブジェクトが1枚の画像にまとめられて処理されます．また，次以降のレイヤーでは通常通りに描画処理が行われるようになります．

このように本来の動作にはあり得ない**不正な**データ操作をしているため，場合によっては不具合が起こります．例えば `Inline Sceneここから` を配置したにも関わらず `Inline Sceneここまで` を置き忘れていた場合，最終的なフレームの描画結果は崩壊した意図しないものになってしまいます．

![画面崩壊の例](https://github.com/user-attachments/assets/1866f93b-9538-4b51-b2d2-0d275816fc54)

不具合が起こると分かっている条件については[うまく動かない使い方](#うまく動かない使い方)を参照してください．

不具合が起こると想定される状態が検出されたり，不具合が起こったであろう痕跡が見つかった場合は patch.aul のコンソールに警告メッセージが出力されます．動画出力をした際などにはこの警告メッセージが出ていないことを確認してください．

![コンソール出力](https://github.com/user-attachments/assets/0c43fe2b-068e-44b8-982d-f9f796018e20)

また，本来のシーン機能では可能な早送り，一時停止などの[時間管理に相当する操作はできません](#早送りや一時停止などの時間操作は未対応)（従ってシーン機能の完全な代替にはなりません）．[音声にも影響はありません](#音声系のオブジェクトに関しては未対応)．

## 使い方

### 基本的な使い方

シーンとしてまとめたい複数レイヤーに対して，次のようにカスタムオブジェクトを配置していきます．

1.  当該複数レイヤーの1つ上に [`Inline Sceneここから`](#inline-sceneここから) を配置．
1.  当該複数レイヤーの1つ下に [`Inline Sceneここまで`](#inline-sceneここまで) を配置．
1.  そのまた1つ下に [`Inline Scene読み出し`](#inline-scene読み出し) を配置．

この `Inline Scene読み出し` のオブジェクトが複数レイヤーをまとめた画像となっていて，通常のシーンオブジェクトに相当するものになります．

`Inline Scene読み出し` で指定する `ILシーン名` は `Inline Sceneここまで` での `ILシーン名` と同じものを指定してください．

![基本レイヤー配置](https://github.com/user-attachments/assets/033dcee5-2d99-4d2d-8bac-727cad785758)

### 派生的な使い方

機能面としては[基本的な使い方](#基本的な使い方)と同じですが，レイヤー数を節約したり配置に自由度ができたりします．

- [`Inline Scene読み出し`](#inline-scene読み出し) は `Inline Sceneここまで` 直下に限らず，もっと下の離れたレイヤーに置くこともできます．レイヤー配分に自由度ができます．

  同じフレームに `Inline Sceneここまで` がなくても動作します．その場合，最後に描画処理のされた inline scene の画像データが使用されるため，描画の重い画像データの手軽なキャッシュとしても利用できます．[`Inline Scene単品保存`](#inline-scene単品保存) も参照．

- [`Inline Sceneここまで`](#inline-sceneここまで) で `描画しない` のチェックを外すと，このオブジェクトがシーンオブジェクトのように振る舞います．そのため `Inline Scene読み出し` を省略でき，レイヤー数を節約できます．

  この場合，`ILシーンに保存` のチェックを外すと，処理が省略されて軽量化に寄与します．

- [`Inline Sceneここまで`](#inline-sceneここまで) と [`Inline Sceneここから`](#inline-sceneここから) をまとめたものとして [`Inline Scene次へ`](#inline-scene次へ) も用意しています．

  「`Inline Sceneここまで` の直下のレイヤーに `Inline Sceneここから`」という配置を 1 レイヤーにまとめて，レイヤーを節約できます．

  ![Inline Scene次への配置例](https://github.com/user-attachments/assets/e420bf0e-bd7b-4b09-84f0-d099310c051e)

  ただしこの場合 `Inline Sceneここまで` のオプションにある `描画しない`, `ILシーンに保存` に相当するものはありません（常に両方とも ON と同等の動作）．

  - 両方とも OFF に相当する動作は「フレームバッファ」オブジェクトで代用できます．

- カスタムオブジェクトの [`Inline Sceneここから`](#inline-sceneここから) を配置する代わりに，inline scene の最初のオブジェクトにアニメーション効果の [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) を適用することもできます．1 レイヤーの節約になります．

  ただし全ての場面で使える方法ではありません（使えない場面の一覧は[こちら](#inline-sceneこのオブジェクトから)）．
  画像オブジェクトや，それに対して縁取りなどの画像加工系のフィルタ効果のみを適用しているオブジェクトなら大体 OK です．

- カスタムオブジェクトの [`Inline Scene次へ`](#inline-scene次へ) を配置する代わりに，次の inline scene の最初のオブジェクトにアニメーション効果の [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) を適用することもでき，1 レイヤーの節約になります．

  ただしこの場合も `Inline Sceneこのオブジェクトから` と同様，全ての場面で使える方法ではありません．

### 応用的な使い方

Inline scene は画像を保存する機能も兼ねていて，同一オブジェクトを使いまわしたり，描画の重い画像のキャッシュをとって再利用することで軽量化させたり，複数の画像を組み合わせるような操作もできます．

- [`Inline Scene単品保存`](#inline-scene単品保存)

  現在オブジェクトの画像データと，座標や回転角度，透明度などの情報を保存します．保存した情報は [`Inline Scene読み出し`](#inline-scene読み出し) で利用できます．

  - グループ制御オブジェクトで設定された座標移動や回転角度は保存されません ．

- [`Inline Scene合成`](#inline-scene合成)

  画像ファイル合成と類似の機能を inline scene のキャッシュ機能で実装したものです．現在オブジェクトの画像に指定した inline scene のキャッシュ画像を，座標や拡大率，回転角度や合成モードなどを指定して合成します．

### その他操作

不具合の起こるような配置がないかどうか検知したり，画像保存機能でのデータを初期化したりといった操作も行えます．余り重用することを想定していない，補助的な診断用スクリプトです．

- [`Inline Scene終了`](#inline-scene終了)

  現在シーンの最下段レイヤーに配置することを想定しているカスタムオブジェクト．このオブジェクトが処理されたタイミングで，`Inline Sceneここまで` で正しく閉じられていない inline scene がある場合，コンソールにエラーメッセージを出力します．

- [`Inline Sceneデータクリア`](#inline-sceneデータクリア)

  `Inline Scene読み出し` などで参照するキャッシュ名とその座標等を保持したデータを削除します．`Inline Scene読み出し` などでは読み出せないようになるため，問題の起こった理由がキャッシュに由来するものなのかどうかを判別するヒントになります．

## 各カスタムオブジェクトの詳細

各オブジェクトの「設定」にある `PI` は parameter injection です．初期値は `nil`. テーブル型を指定すると `obj.check0` や `obj.track0` などの代替値として使用されます．また，任意のスクリプトコードを実行する記述領域にもなります．

```lua
_0 = {
  [0] = check0, -- boolean または number (~= 0 で true 扱い). obj.check0 の代替値．それ以外の型だと無視．
  [1] = track0, -- number 型．obj.track0 の代替値．tonumber() して nil な場合は無視．
  [2] = track1, -- obj.track1 の代替値．その他は [1] と同様．
  [3] = track2, -- obj.track2 の代替値．その他は [1] と同様．
  [4] = track3, -- obj.track3 の代替値．その他は [1] と同様．
}
```

### `Inline Sceneここから`

Inline scene を始めます．既に始まっている場合は入れ子の階層が1つ増えます．

- このオブジェクトはカメラ制御の配下には配置しないでください．
- 始めた inline scene は [`Inline Sceneここまで`](#inline-sceneここまで) で閉じてください．
  - 閉じていない場合，次に inline scene 関連の処理がされたときにエラーメッセージをコンソールに出力します．

#### 設定値

1.  `アルファチャンネルあり`

    始める inline scene が，シーンの「アルファチャンネルあり」に相当する挙動かを指定．初期値は ON.

### `Inline Sceneここまで`

Inline scene を閉じます．複数の inline scene の入れ子階層がある場合は，階層を1つ減らします．

- このオブジェクトはカメラ制御の配下には配置しないでください．
- Inline scene が始まっていない場合はエラーメッセージをコンソールに出力します．

#### 設定値

1.  `上余白` / `下余白` / `左余白` / `右余白`

    取得する inline scene に設定する余白量をピクセル単位で，上下左右個別に指定します．正の値で画像が広がり，負の値だとクリッピングします．初期値は `0`.

1.  `余白を除去`

    取得する inline scene 画像を不透明ピクセルを含む最小の矩形に制限します．`上余白` などによる画像サイズ調整はこの後に処理されます．OFF だと現在シーンの画像サイズそのままが使用されます．初期値は ON.

1.  `描画しない`

    取得した inline scene を，このオブジェクトではフレームバッファに描画しません．後に [`Inline Scene読み出し`](#inline-scene読み出し) などで利用することを想定します．後続フィルタ効果も処理されません．OFF にすると，通常通り後続フィルタ効果が処理されていきます．初期値は ON. 

1.  `ILシーンに保存` / `ILシーン名`

    取得した inline scene に名前を付けて保存，後に `Inline scene 読み出し` などで利用できるようにします．初期値は ON / `scn1`.

    - `ILシーン` は `InLine シーン` の略です．

### `Inline Scene読み出し`

Inline scene として保存したキャッシュを読み込みます．[`Inline Scene単品保存`](#inline-scene単品保存) で保存したキャッシュにも対応しています．読み出した際には，オブジェクトの位置，回転角度，拡大率や透明度なども復元することができます．

#### 設定値

1.  `位置や回転も復元`

    キャッシュ取得時に保存した位置，回転角度，拡大率や透明度などのデータも復元します．OFF だと基本的には画像の中心に中央揃えで，回転角などは初期値のまま配置されます．初期値は ON.

1.  `ILシーン名`

    読み出す対象の inline scene の名前を指定します．初期値は `scn1`.

1.  `現在フレーム`

    読み出す対象を，現在フレームで作成された inline scene やキャッシュに限るかどうかを指定します．初期値は OFF.

### `Inline Scene次へ`

[`Inline Sceneここまで`](#inline-sceneここまで) の直下のレイヤーに [`Inline Sceneここから`](#inline-sceneここから) を配置したのと同様の処理を行います．オブジェクトやレイヤー数を節約できますし，実際の処理は画像のコピー回数なども削減されるため，軽量化に寄与します．

- ただし `描画しない` / `ILシーンに保存` に相当する設定はありません．両方とも ON 相当の挙動です．

#### 設定値

1.  `上余白` / `下余白` / `左余白` / `右余白` / `ILシーン名` / `余白を除去`

    `Inline Sceneここまで` の同名のものと同等の設定項目です．

1.  `アルファチャンネルあり`

    `Inline Sceneここから` の同名のものと同等の設定項目です．

### `Inline Scene終了`

このオブジェクトの処理時に inline scene が開いている場合，inline scene を全て閉じます．

診断用です．シーンの最下段レイヤーに配置して，閉じ忘れた inline scene の検出に利用できます．

#### 設定値

1.  `有効動作時コンソールに出力`

    閉じ忘れの inline scene を検出した際，コンソールにその旨の[メッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)を出力します．

### `Inline Sceneデータクリア`

Inline scene の管理するキャッシュ名とその座標等を保持したデータを削除します．診断用です．キャッシュに依存する問題特定に利用できます．

#### 設定値

1.  `全シーン分初期化`

    Inline scene のキャッシュは (本物の) シーンごとに個別に管理されています．この設定が OFF だと，このオブジェクトの置かれたシーンのキャッシュのみ削除します．ON だと50個あるシーン全てに対して適用します．

## アニメーション効果の詳細

[カスタムオブジェクトと同様](#各カスタムオブジェクトの詳細)に `PI` という名前の項目で parameter injection が可能です．

### `Inline Sceneこのオブジェクトから`

[`Inline Sceneここから`](#inline-sceneここから) の機能をアニメーション効果として利用できます．Inline scene の最上段レイヤーのオブジェクトに適用してください．

**以下の場合は正しく動作しないことがあります．** この場合はカスタムオブジェクト版の `Inline Sceneここから` を使用してください．

1.  カメラ制御の配下にあるオブジェクト．
1.  「個別オブジェクト」なオブジェクト．
1.  カスタムオブジェクトで，引数なしの `obj.effect()` 呼び出しを利用したもの．
1.  アニメーション効果などで，引数なしの `obj.effect()` 呼び出しを利用したものの後続フィルタとして適用．
1.  カスタムオブジェクトで，フレームバッファに直接描画するようなもの．または，そういったアニメーション効果などの後続フィルタとして適用．

参考: [カメラ制御の場合](#カメラ制御との併用)，[個別オブジェクトの場合](#個別オブジェクトとの併用)，[`obj.effect()` の場合](#一部のカスタムオブジェクトやアニメーション効果との組み合わせ)，[フレームバッファに直接描画の場合](#アニメーション効果が無効化される場面)．

#### 設定値

1.  `アルファチャンネルあり`

    `Inline Sceneここから` の同名のものと同等の設定項目です．

### `Inline Sceneこのオブジェクトで次へ`

[`Inline Scene次へ`](#inline-scene次へ) の機能をアニメーション効果として利用できます．*次の* inline scene の最上段レイヤーにあるオブジェクトに適用してください．

- [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) と同様の条件で正しく動作しません．その場合はカスタムオブジェクト版の `Inline Scene次へ` を使用してください．

#### 設定値

1.  `上余白` / `下余白` / `左余白` / `右余白` / `アルファチャンネルあり` / `ILシーン名` / `余白を除去`

    `Inline Scene次へ` の同名のものと同等の設定項目です．

### `Inline Scene単品保存`

現在オブジェクトの画像データと，座標や回転角度，透明度などの情報を保存します．保存した情報は [`Inline Scene読み出し`](#inline-scene読み出し) で利用できます．

- 保存する情報は以下の通り．

  1.  画像データ，ピクセルサイズ.
  1.  位置 (`obj.x + obj.ox, obj.y + obj.oy, obj.z + obj.oz` に相当).
  1.  回転中心 (`obj.cx, obj.cy, obj.cz` に相当).
  1.  回転角度 (`obj.rx, obj.ry, obj.rz` に相当).
  1.  拡大率，縦横比 (`obj.zoom, obj.aspect` と `obj.getvalue("zoom"), obj.getvalue("aspect")` の合成に相当).
  1.  透明度 (`obj.alpha * obj.getvalue("alpha")` に相当).

- オブジェクト個数が 2 以上の個別オブジェクトに対しては適用できません．

#### 設定値

1.  `描画しない`

    保存したオブジェクトを，このオブジェクトではフレームバッファに描画しません．後続フィルタ効果も処理されません．OFF にすると，通常通り後続フィルタ効果が処理されていきます．初期値は ON.

1.  `ILシーン名`

    保存先の，`Inline Scene読み出し` などで使用できるキャッシュ名．初期値は `scn1`.

### `Inline Scene合成`

画像ファイル合成と類似の機能を inline scene のキャッシュで適用します．

#### 設定値

1.  `X` / `Y`

    キャッシュ画像を合成する位置をピクセル単位で指定します．アンカー操作でも移動できます．初期値は原点 $(0, 0)$.

1.  `拡大率`

    キャッシュ画像の拡大率を % 単位で指定します．初期値は `100.00` (等倍).

1.  `透明度`

    キャッシュ画像の透明度を % 単位で指定します．初期値は `0.00` (完全不透明).

1.  `回転角度`

    キャッシュ画像の回転角度を度数法で，時計回りに正で指定します．初期値は `0.0`.

1.  `後方から合成`

    現在オブジェクトの背面にキャッシュ画像を配置した画像を作成します．初期値は OFF.

1.  `合成モード`

    合成に使用する合成モードを指定します．初期値は `通常`. 

    <details>
    <summary>利用可能な値は以下の通り:</summary>

    - `通常`
    - `加算`
    - `減算`
    - `乗算`
    - `スクリーン`
    - `オーバーレイ`
    - `比較(明)`, `比較（明）`
    - `比較(暗)`, `比較（暗）`
    - `輝度`
    - `色差`
    - `陰影`
    - `明暗`
    - `差分`
    - `alpha_add`
    - `alpha_max`
    - `alpha_sub`
    - `alpha_add2`
    - 任意の `0` 以上の整数

      そのまま `obj.setoption("blend", ...)` の引数として使用されます．

    上記のどれにも当てはまらない場合は `通常` となります．
    </details>

1.  `ループ画像`

    キャッシュ画像をループさせて合成します．初期値は OFF.

1.  `ILシーン名` / `現在フレーム`

    [`Inline Scene読み出し`](#inline-scene読み出し) の同名のものと同等の設定項目です．


## うまく動かない使い方

[仕組み](#仕組み)で述べた通り，このスクリプトは AviUtl のメモリに直接介入することで実現しています．条件によってはこの介入が不具合を引き起こすこともあります．他にも AviUtl やスクリプトの仕様の都合上，意図しなかったり不自然に思える挙動になることもあるのでここで紹介します．

### カメラ制御との併用

次のオブジェクトはカメラ制御の配下（カメラ制御の範囲内でかつ，カメラ制御有効のボタンを ON にした状態）に配置しないでください:

- カスタムオブジェクトの [`Inline Sceneここから`](#inline-sceneここから), [`Inline Scene次へ`](#inline-scene次へ), [`Inline Sceneここまで`](#inline-sceneここまで) と [`Inline Scene終了`](#inline-scene終了).
- アニメーション効果の [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) と [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) を付けたオブジェクト．

カメラ制御配下だとメモリ介入で予期せぬ描画結果になることを確認しています．この場合，コンソールに[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)を出力します．

対処法としては，カメラ制御は inline scene の境界をまたぐようには配置しないようにしてください．また `Inline Sceneここまで` をカメラ制御下にするのではなく，`描画しない` と `ILシーンに保存` にチェックを入れて，その直下に [`Inline Scene読み出し`](#inline-scene読み出し) を配置してカメラ制御の対象にしてください．

### 個別オブジェクトとの併用

次のアニメーション効果やフィルタ効果は個別オブジェクトなオブジェクトには適用しないでください:

- [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから)
- [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ)
- [`Inline Scene単品保存`](#inline-scene単品保存) (オブジェクト個数が 2 以上の場合)

最初の2つについて，個別オブジェクトに対してはこのスクリプトによるメモリ介入が意図した通りに動かない場面を確認しています．また，一般に不定回数だけ inline scene の階層を操作することになり，アニメーション効果の適用先として不適格とも判断しています．コンソールに[エラーメッセージ](#スクリプト名-は個別オブジェクトには適用しないでください)を出力します．

対処法としては，アニメーション効果ではなく，対応するカスタムオブジェクトの方を配置してください:

- `Inline Sceneこのオブジェクトから` ではなく [`Inline Sceneここから`](#inline-sceneここから) を使用．
- `Inline Sceneこのオブジェクトで次へ` ではなく [`Inline Scene次へ`](#inline-scene次へ) を使用．

最後の1つは，個別にオブジェクトが同じ `ILシーン名` に上書きされていく結果となり，無駄でしかないため意図しないものと判断しています．有効利用したい場合は，スクリプト制御から直接 [`save()`](#savename-scene_idx) 関数を呼び出すなどしてください．

### 一部のカスタムオブジェクトやアニメーション効果との組み合わせ

アニメーション効果の [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) や [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) などは次の場合には動作しません:

- カスタムオブジェクトで，引数なしの `obj.effect()` 呼び出しを利用したものに適用．
- アニメーション効果などで，引数なしの `obj.effect()` 呼び出しを利用したものの後続フィルタとして適用．

この状況だとこのスクリプトによるメモリ介入が意図した通りに動かないことを確認しています．コンソールに[エラーメッセージ](#スクリプト名-は-objeffect-の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません)を出力します．

対処法としては，アニメーション効果ではなく，対応するカスタムオブジェクトの方を配置してください:

- `Inline Sceneこのオブジェクトから` ではなく [`Inline Sceneここから`](#inline-sceneここから) を使用．
- `Inline Sceneこのオブジェクトで次へ` ではなく [`Inline Scene次へ`](#inline-scene次へ) を使用．

### アニメーション効果が無効化される場面

このスクリプトに限らず，アニメーション効果は次の場合には動作しません:

- カスタムオブジェクトに適用していて，そのカスタムオブジェクトが引数なしの `obj.effect()` を呼ばずに直接フレームバッファに描画している場合．
- アニメーション効果の後続フィルタとして適用していてそのアニメーション効果が同様に，引数なしの `obj.effect()` を呼ばずに直接フレームバッファに描画している場合．
- 画像のピクセルサイズが 0 の場合．

  例えば...
  - クリッピングで画像サイズを超えて切り取る，
  - テキストオブジェクトで，テキストが空欄．

この場合 [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) などが動作せず，[エラーメッセージ](#inline-scene-が開いていない状態で-スクリプト名-が適用されました-inline-scene-オブジェクト--フィルタ効果の配置が正しくない可能性があります)につながることもあります．見落としもしやすいので注意してください．

### カメラ制御のグリッド表示

`アルファチャンネルあり` が ON の inline scene 内でカメラ制御を使用した場合，カメラ制御のグリッドが正しく表示されません．

![カメラ制御のグリッド表示がおかしくなる例](https://github.com/user-attachments/assets/f96f302c-f58d-4049-b87a-2848e8b00117)

出力動画やプレビュー再生中の表示には影響しませんが，編集作業に支障が出る場合は以下のような対処法があります:

- カメラ制御のグリッドを非表示にする．

  - タイムラインを右クリックした際のメニューから切り替えられます．

- Inline scene を一時的に無効化する．
- Inline scene の `アルファチャンネルあり` を一時的に OFF にする．

### アルファチャンネルありでのフィルタオブジェクト

フィルタオブジェクトの挙動にも影響することを確認しています:

- `アルファチャンネルあり` が ON の inline scene 内でフィルタオブジェクトは動作しません．これは `アルファチャンネルあり` が ON の*通常の*シーンでもフィルタオブジェクトが動作しないのと類似の挙動です．

- `アルファチャンネルあり` が ON の*通常の*シーン内で `アルファチャンネルあり` が OFF の inline scene を用意し，その中でフィルタオブジェクトを配置した場合，そのシーンのプレビュー表示では動作していませんしオブジェクトの表示も灰色（無効化の色表示）になっていますが，シーンオブジェクト経由で表示させると動作します．

ただし，`アルファチャンネルあり` が OFF の状態でも inline scene 内でシーンチェンジは[正しく動作しません](#inline-scene-内でのシーンチェンジ)．

### Inline Scene 内でのシーンチェンジ

Inline scene 内ではシーンチェンジは正しく動作しないため，配置しないでください．正確には，シーンチェンジオブジェクトの開始フレームより 1 フレーム直前の位置が inline scene の中だった場合にも問題になります．

シーンチェンジはこの 1 フレーム直前のフレーム描画を行いますが（中間点がある場合は，その中間点も），シーンチェンジオブジェクトが置かれたレイヤーの 1 つ上までしか処理をしません．そのため inline scene が閉じられずに意図した動作や描画結果になりません．

[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)の原因にもなります．

### 早送りや一時停止などの時間操作は未対応

通常のシーンにあるような，開始位置の指定や早送り / 一時停止といった機能はありません．

- Inline scene 内に時間制御オブジェクトを配置することで表現できることもあります．
- [`Inline Scene読み出し`](#inline-scene読み出し) を時間制御オブジェクトの配下に配置しても，読み出されるキャッシュ画像には影響せず，通常の再生速度のままです．`Inline Scene読み出し` オブジェクトに配置されたトラックバーの変化などだけが影響を受けます．

### 音声系のオブジェクトに関しては未対応

通常のシーンとは違い，このスクリプトが介入しているのは画像描画部分のみなので，音声系オブジェクトには影響がありません．（そもそも AviUtl スクリプトで音声系に作用させられる API は未搭載．）

### 編集作業中の場合，`ILシーン名` は最後に使用してから 5 分以上経つと無効

入力途中の `ILシーン名` で無駄なキャッシュが肥大化していくのを避けるため，`ILシーン名` に 5 分の有効期限を設けています． ただし動画出力中やプレビュー再生中はこの制約を受けません．

## エラーメッセージ

ほとんどのエラーメッセージの冒頭には `[Inline Scene] <シーン名/番号>, Frame: <フレーム番号>, Layer: <レイヤー番号>` と書かれています．この表記位置付近に問題が起こっている可能性が高いため，優先的に調べるのがよいでしょう．

### Inline Scene が正しく閉じられなかった可能性があります! (検出は Frame: <フレーム番号>, Layer: <レイヤー番号> の "<スクリプト名>")

[`Inline Sceneここまで`](#inline-sceneここまで) が下段のレイヤーに配置されていない，あるいは何かの理由で無効化されているときに起こるエラーです．多くの場合はフレーム画像が崩壊します．

Inline scene の下段のレイヤーに正しく `Inline Sceneここまで` が配置されているか，フレームずれなどを起こしていないかなどを確認してください．また，[シーンチェンジを inline scene 内に配置している場合](#inline-scene-内でのシーンチェンジ)にもこのメッセージが出ることがあります．

エラーの検出はエラーが起こったタイミングではなく，次回以降のフレーム描画処理で inline scene 関連のスクリプトが実行されたタイミングです．なので動画の最終フレームなどに起こったエラーは検知されません．確実に検知するためには [`Inline Scene終了`](#inline-scene終了) を最下段レイヤーに配置してください．

通常の編集手順や途中経過でも起こる，最もよく見ることになるエラーメッセージの1つです．

### Inline Scene が開いていない状態で "<スクリプト名>" が適用されました! Inline Scene オブジェクト / フィルタ効果の配置が正しくない可能性があります!

[`Inline Sceneここまで`](#inline-sceneここまで) や [`Inline Scene次へ`](#inline-scene次へ) などが inline scene でない場所に配置されたときに起こるエラーです．

[`Inline Sceneここから`](#inline-sceneここから) や [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) が正しく配置されているか，何らかの理由で無効化されていないかなどを確認してください．特に `Inline Sceneこのオブジェクトから` が適用されているオブジェクトが，[画像サイズが 0 だったり後続フィルタを無視するようなカスタムオブジェクトやアニメーション効果を適用](#アニメーション効果が無効化される場面)している場合にも，このエラーが発生することがあります．

こちらも通常の編集手順や途中経過でも起こる，最も奥見ることになるエラーメッセージの1つです．

### "<スクリプト名>" は obj.effect() の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません!

[`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) や [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) などが，スクリプトで引数なしの `obj.effect()` 経由で実行された場合に起こります．

対処法は[こちら](#一部のカスタムオブジェクトやアニメーション効果との組み合わせ)．

### "<スクリプト名>" は個別オブジェクトには適用しないでください!

[`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから) や [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) などを個別オブジェクトなオブジェクトに対して適用した場合に起こります．

対処法は[こちら](#個別オブジェクトとの併用)．

### "<スクリプト名>" はカメラ制御下には配置しないでください!

次のオブジェクトをカメラ制御の配下に配置した場合に起こるエラーです:

- カスタムオブジェクトの [`Inline Sceneここから`](#inline-sceneここから), [`Inline Scene次へ`](#inline-sceneここから) と [`Inline Sceneここまで`](#inline-sceneここまで).
- アニメーション効果の [`Inline Sceneこのオブジェクトから`](#inline-sceneこのオブジェクトから), [`Inline Sceneこのオブジェクトで次へ`](#inline-sceneこのオブジェクトで次へ) を適用しているオブジェクト．

対処法は[こちら](#カメラ制御との併用)．

### キャッシュ "cache:<文字列>" を読み込めませんでした．patch.aul の設定 patch.aul.json で "switch" -> "shared_cache" が true になっているのを確認し，AviUtl の設定で「キャッシュサイズ」を見直してみてください．

このスクリプトは patch.aul による共有メモリを利用したキャッシュ機能で寿命が延びたキャッシュを利用しています．寿命が延びたとはいえ，このキャッシュは AviUtl の他の機能のメモリ使用状況によっては容量を逼迫し自動解放されてしまうこともあります．そういった解放されたキャッシュを利用しようとした際に起こるエラーです．

対処法としては AviUtl のキャッシュサイズを上げる（PC のメモリの半分くらいが相場とされている），他のメモリを圧迫するような機能の使用を控えるなどが挙げられます．

また拡張編集のメニューコマンド「キャッシュを破棄」(既定のショートカットキーは F5) を使用することでも，このエラーメッセージが起こることがあります．

### その他実行環境に問題がある場合のエラーメッセージ

[動作要件](#動作要件)を確認してください．

- このスクリプトの実行には patch.aul が必要です!
- このスクリプトの実行には patch.aul の設定 patch.aul.json で "switch" -> "lua.getvalue" が true である必要があります!
- このスクリプトの実行には LuaJIT が必要です!

なお以下のメッセージもソースには書かれていますが，patch.aul の導入確認後に冗長的にチェックされているので出てこないはずです．

- AviUtl のバージョンが 1.10 ではありません!
- 拡張編集が見つかりません!
- 拡張編集のバージョンが 0.92 ではありません!


## TIPS

1.  Inline scene は入れ子にできます --- inline scene の中にまた「子 inline scene」を配置することもできます．

1.  別シーンに配置した inline scene は，同じ `ILシーン名` を指定していたとしても別物扱いになります．

1.  `ILシーン名` の有効期限の 5 分は `InlineScene_S.lua` を編集することで変更できます．

    テキストエディタで `InlineScene_S.lua` 開くと冒頭付近に次の行があり，有効期限を指定しています．値は秒単位です．
      ```lua
      local interval_collection = 300;
      ```

1.  [エラーメッセージ](#エラーメッセージ)の色やスタイルは `InlineScene_S.lua` 冒頭付近の `warning_style_lead`, `warning_style_body` を編集することで変更できます．文字色が見にくい場合などは付近のコメント文も参考に調整してください．

    参考: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors

    - `warning_style_lead` はエラーメッセージ冒頭の，問題の発生位置を示す部分の色やスタイルです．初期値は `"\27[91m\27[4m"`, 明るい赤で下線ありの設定です．

    - `warning_style_body` はエラーメッセージ本文の色やスタイルです．初期値は `"\27[31m\27[24m"`, 赤色で下線なしの設定です．

1.  テキストエディタで `@InlineScene_S.anm`, `@InlineScene_S.obj`, `InlineScene_S.lua` を開くと冒頭付近にファイルバージョンが付記されています．

    ```lua
    --
    -- VERSION: v1.00
    --
    ```

    ファイル間でバージョンが異なる場合，更新漏れの可能性があるためご確認ください．

## スクリプト API

このスクリプトは，Inline Scene としてや [`Inline Scene単品保存`](#inline-scene単品保存) を使って保存したり，[`Inline Scene読み出し`](#inline-scene読み出し) で読み出せるキャッシュ画像を，外部スクリプトからを取得 / 保存できるような API を備えています．

`InlineScene_S.lua` をその外部スクリプトが見つけられるようにして置いた上で，
```lua
local ils = require "InlineScene_S"
```
と記述してください．`ils` は以下の関数を持っていて，外部から利用することも想定しています．各関数の説明は `InlineScene_S.lua` のドキュメントコメントにも記述があります．

- 例:
  ```lua
  -- "my_inline_scene" の名前で保存された inline scene を取得．
  local cache_name, metrics, status, age = ils.read_scene("my_inline_scene")
  if status then -- 未保存なら `status` は `nil`.
    -- 画像データを読み出す．
    obj.copybuffer("obj", cache_name)

    -- 画像データの縦横サイズや，保存時の X, Y 座標を取得．
    local w, h, ox, oy = metrics.w, metrics.h, metrics.ox, metrics.oy

    -- ...
  end
  ```

> [!TIP]
> 次の関数は他の関数の応用です; 本質的に `ils` 内にある他の関数を組み合わせて実現できるものなので，応用スクリプトを記述する際の参考になるかもしれません．
> 1.  [`save()`](#savename-scene_idx)
> 1.  [`recall()`](#recallname-restore_metrics-curr_frame-scene_idx)
> 1.  [`combine()`](#combinename-curr_frame-x-y-zoom-alpha-angle-loop-back-blend-scene_idx) 

### `Begin(has_alpha)`

[`Inline Sceneここから`](#inline-sceneここから) のメイン処理．

Inline scene の状態を開始する．

フレームバッファをキャッシュに退避し消去，一部フラグを書き換える．次の [`End()`](#endcrop-ext_l-ext_t-ext_r-ext_b-name) の呼び出しで復元される．

`tempbuffer` は他データで上書きされるので注意．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`has_alpha`|boolean|開始した inline scene が「アルファチャンネルあり」に相当する挙動かどうかを指定する．|
|戻り値|なし|||

- 以下の場面でエラーメッセージを出力する．
  - 前回のフレーム描画時に閉じ忘れの inline scene があったのを検出した場合．[[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)]
  - カメラ制御配下のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 「個別オブジェクト」のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 引数なし `obj.effect()` 呼び出しの過程での呼び出し．[[エラーメッセージ](#スクリプト名-は-objeffect-の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません)]

### `End(crop, ext_l, ext_t, ext_r, ext_b, name)`

[`Inline Sceneここまで`](#inline-sceneここまで) のメイン処理．

Inline scene の状態を終了する．

現在のフレームバッファをオブジェクトやキャッシュとして再利用可能にして，[`Begin()`](#beginhas_alpha) で退避したフレームバッファとフラグを復元する．

現在オブジェクトの内容はフレームバッファの内容で上書きされる．余白調整量に応じて `obj.cx`, `obj.cy` も変化する．`tempbuffer` は他データで上書きされるので注意．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`crop`|boolean\|nil|上下左右の完全透明ピクセルを取り除く．既定値は `false`.|
|引数 #2|`ext_l`|integer|描画・保存前に追加する左余白幅．負だとクリッピング．|
|引数 #3|`ext_t`|integer|描画・保存前に追加する上余白幅．負だとクリッピング．|
|引数 #4|`ext_r`|integer|描画・保存前に追加する右余白幅．負だとクリッピング．|
|引数 #5|`ext_b`|integer|描画・保存前に追加する下余白幅．負だとクリッピング．|
|引数 #6|`name`|string\|nil|Inline scene として保存する場合の名前．この名前は [`recall()`](#recallname-restore_metrics-curr_frame-scene_idx) や [`save()`](#savename-scene_idx), [`read_cache()`](#read_cachename-scene_idx), [`write_cache()`](#write_cachename-scene_idx) などで利用できる．`nil` の場合は保存しない．|
|戻り値|なし|||

- 以下の場面でエラーメッセージを出力する．
  - 前回のフレーム描画時に閉じ忘れの inline scene があったのを検出した場合．[[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)]
  - Inline scene が開かれていない場合．[[エラーメッセージ](#inline-scene-が開いていない状態で-スクリプト名-が適用されました-inline-scene-オブジェクト--フィルタ効果の配置が正しくない可能性があります)]
  - カメラ制御配下のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 「個別オブジェクト」のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 引数なし `obj.effect()` 呼び出しの過程での呼び出し．[[エラーメッセージ](#スクリプト名-は-objeffect-の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません)]

### `Next(crop, ext_l, ext_t, ext_r, ext_b, name, has_alpha)`

[`Inline Scene次へ`](#inline-scene次へ) のメイン処理．

[`End()`](#endcrop-ext_l-ext_t-ext_r-ext_b-name) を呼び出し，その後に [`Begin()`](#beginhas_alpha) を呼び出すのに相当する処理をする．ただしコピー回数が少なく，現在オブジェクトの内容や `obj.cx`, `obj.cy` が変化しない点が異なる．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`crop`|boolean\|nil|上下左右の完全透明ピクセルを取り除く．既定値は `false`.|
|引数 #2|`ext_l`|integer|描画・保存前に追加する左余白幅．負だとクリッピング．|
|引数 #3|`ext_t`|integer|描画・保存前に追加する上余白幅．負だとクリッピング．|
|引数 #4|`ext_r`|integer|描画・保存前に追加する右余白幅．負だとクリッピング．|
|引数 #5|`ext_b`|integer|描画・保存前に追加する下余白幅．負だとクリッピング．|
|引数 #6|`name`|string|Inline scene として保存する場合の名前．この名前は [`recall()`](#recallname-restore_metrics-curr_frame-scene_idx) や [`save()`](#savename-scene_idx), [`read_cache()`](#read_cachename-scene_idx), [`write_cache()`](#write_cachename-scene_idx) などで利用できる．|
|引数 #7|`has_alpha`|boolean|*次の* inline scene が「アルファチャンネルあり」に相当する挙動かどうかを指定する．|
|戻り値|なし|||

- 以下の場面でエラーメッセージを出力する．
  - 前回のフレーム描画時に閉じ忘れの inline scene があったのを検出した場合．[[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)]
  - Inline scene が開かれていない場合．[[エラーメッセージ](#inline-scene-が開いていない状態で-スクリプト名-が適用されました-inline-scene-オブジェクト--フィルタ効果の配置が正しくない可能性があります)]
  - カメラ制御配下のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 「個別オブジェクト」のとき．[[エラーメッセージ](#スクリプト名-はカメラ制御下には配置しないでください)]
  - 引数なし `obj.effect()` 呼び出しの過程での呼び出し．[[エラーメッセージ](#スクリプト名-は-objeffect-の引数なし呼び出しを含むスクリプトの後続フィルタとして配置できません)]

### `Quit(do_warn)`

[`Inline Scene終了`](#inline-scene終了) のメイン処理．

Inline scene の状態を，入れ子状態のものも含めて全て強制終了する．条件に応じて[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)を出力する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`do_warn`|boolean|強制終了が実行されたならコンソールにメッセージを表示するかどうかを指定．`true` で出力する，`false` でしない．|
|戻り値|なし|||

### `Status()`

Inline scene や現在のシーンそのものの状態を取得する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数|なし|||
|戻り値 #1|`ils_depth`|integer|Inline scene の入れ子階層の深さ．Inline scene が開いていない状態だと `0`.|
|戻り値 #2|`has_alpha`|boolean|フレームバッファのアルファチャンネルが有効な場合 `true`, 無効な場合 `false`.|
|戻り値 #3|`is_nesting`|boolean|シーンオブジェクトやシーンチェンジなのでシーンのフレーム画像取得が行われている場合 `true`, それ以外は `false`.|

- `has_alpha` と `is_nesting` は inline scene による介入で上書きされた後のデータ．
- 前回のフレーム描画時に閉じ忘れの inline scene があったのを検出した場合[[エラーメッセージ](#inline-scene-が正しく閉じられなかった可能性があります-検出は-frame-フレーム番号-layer-レイヤー番号-の-スクリプト名)]を出力する．

### `save(name, scene_idx)`

[`Inline Scene単品保存`](#inline-scene単品保存) のメイン処理．

指定した名前の inline scene に現在のオブジェクトの画像データを保存する．Inline scene に既存のデータは破棄される．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`name`|string|Inline scene の名前．|
|引数 #2|`scene_idx`|integer\|string\|nil|対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|戻り値|なし|||

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

### `recall(name, restore_metrics, curr_frame, scene_idx)`

[`Inline Scene読み出し`](#inline-scene読み出し) のメイン処理．

Inline scene を現在のオブジェクトとして読み込む．オプションで回転角や中心座標も復元する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`name`|string|Inline scene の名前を指定．|
|引数 #2|`restore_metrics`|boolean|相対座標や回転角度，回転中心などを復元するかどうかを指定．|
|引数 #3|`curr_frame`|boolean\|nil|現在フレームで合成された inline scene のみを対象にするかどうかを指定．既定値は `false`.|
|引数 #4|`scene_idx`|integer\|string\|nil|対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|戻り値 #1|`success`|boolean|正しく inline scene が読み込まれた場合は `true`, エラーなら `false`.|

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

- 読み込みを試みたキャッシュが AviUtl によって既に破棄されていた場合，[エラーメッセージ](#キャッシュ-cache文字列-を読み込めませんでしたpatchaul-の設定-patchauljson-で-switch---shared_cache-が-true-になっているのを確認しaviutl-の設定でキャッシュサイズを見直してみてください)を出力する．

### `combine(name, curr_frame, x, y, zoom, alpha, angle, loop, back, blend, scene_idx)`

[`Inline Scene合成`](#inline-scene合成) のメイン処理．

指定した inline scene と現在のオブジェクトを合成する．

処理中に `tempbuffer` を上書きする．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`name`|string|Inline scene の名前を指定．|
|引数 #2|`curr_frame`|boolean\|nil|現在フレームで合成された inline scene のみを対象にするかどうかを指定．既定値は `false`.|
|引数 #3|`x`|number|合成の基準位置の X 座標．|
|引数 #4|`y`|number|合成の基準位置の Y 座標．|
|引数 #5|`zoom`|number|拡大率，等倍は `1.0`.|
|引数 #6|`alpha`|number|不透明度，完全不透明は `1.0`.|
|引数 #7|`angle`|number|回転角度，度数法で時計回りに正．|
|引数 #8|`loop`|boolean|画像ループをする場合は `true`, しない場合は `false`.|
|引数 #9|`back`|boolean|背面から合成する場合は `true`, 通常通り前面からの場合は `false`.|
|引数 #10|`blend`|integer\|string\|nil|合成モードを指定 `0`, `"加算"`, `"alpha_sub"` などが使える．`nil` だと通常の合成モード．|
|引数 #11|`scene_idx`|integer\|string\|nil|対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|戻り値|なし|||

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

### `read_cache(name, scene_idx)`

Inline scene 管理下のキャッシュデータを読み出し目的で取得．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`name`|string|Inline scene の名前．|
|引数 #2|`scene_idx`|integer\|string\|nil|取得対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|戻り値 #1|`cache_name`|string|`obj.copybuffer()` で使える `"cache:"` から始まるキャッシュ名．|
|戻り値 #2|`metrics`|[metrics_tbl](#metrics_tbl-テーブル)|Inline scene のサイズや位置，回転角度の情報を格納したテーブル．`read_cache()` で取得した場合は中身を上書きしないこと．|
|戻り値 #3|`status`|`"yet"`\|`"new"`\|`"old"`\|nil|Inline scene が最後に書き込まれた段階を表す．<br>`"yet"`: 現在よりも後の段階（同一フレームの再描画や巻き戻しなどが起こった），<br>`"new"`: 現在よりも前の段階で，同一フレーム，<br>`"old"`: 現在よりも前のフレーム,<br>`nil`: そもそも書き込みが起こっていない．|
|戻り値 #4|`age`|integer\|nil|Inline scene が最後に書き込まれてからの経過フレーム数．`status` が `nil` の場合は `nil`.|

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

### `write_cache(name, scene_idx)`

Inline scene 管理下のキャッシュデータを書き込み目的で取得．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`name`|string|Inline scene の名前．|
|引数 #2|`scene_idx`|integer\|string\|nil|取得対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|戻り値 #1|`cache_name`|string|`obj.copybuffer()` で使える `"cache:"` から始まるキャッシュ名．|
|戻り値 #2|`metrics`|[metrics_tbl](#metrics_tbl-テーブル)|Inline scene のサイズや位置，回転角度の情報を格納したテーブル．更新が必要なら中身を書き換えること．|
|戻り値 #3|`status`|`"yet"`\|`"new"`\|`"old"`\|nil|Inline scene が最後に書き込まれた段階を表す．<br>`"yet"`: 現在よりも後の段階（同一フレームの再描画や巻き戻しなどが起こった），<br>`"new"`: 現在よりも前の段階で，同一フレーム，<br>`"old"`: 現在よりも前のフレーム,<br>`nil`: そもそも書き込みが起こっていない．|
|戻り値 #4|`age`|integer\|nil|Inline scene が最後に書き込まれてからの経過フレーム数．`status` が `nil` の場合は `nil`.|

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

### `clear_caches(scene_idx, all)`

[`Inline Sceneデータクリア`](#inline-sceneデータクリア) のメイン処理．

Inline scene のデータを破棄する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`scene_idx`|integer\|string\|nil|破棄対象のシーン番号，または独自の名前．`nil` の場合は現在オブジェクトのシーン番号．|
|引数 #2|`all`|boolean\|nil|全てのシーン番号と独自名に属するデータを破棄する．既定値は `false`.|
|戻り値|なし|||

- `scene_idx` にはアプリケーション固有の文字列も可能 (`"my_app"` など).

### `scene_frame()`

現在シーンの冒頭からのフレーム数を取得する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数|なし|||
|戻り値 #1||integer|フレーム数，冒頭は `0`.|

### `scene_index()`

現在のオブジェクトのシーン番号を取得する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数|なし|||
|戻り値 #1|`scene_idx`|integer|Root は `0`, Scene 1 は `1`, ...|

### `offscreen_drawn()`

現在オブジェクトが「オフスクリーン描画」が実行された後の状態で，座標関連の取り扱いが特殊な状況であるかどうかを取得する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数|なし|||
|戻り値 #1||boolean|`true` で「オフスクリーン描画」済み，`false` で「オフスクリーン描画」がされていない．|

### `is_playing()`

現在プレビュー再生中であるかどうかを取得する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数|なし|||
|戻り値 #1||boolean|`true` だとプレビュー再生中，`false` だと編集作業中．|

- 保存中 (`obj.getinfo("saving")` が `true`) の場合の戻り値は `false`.

### `bounding_box(left, top, right, bottom)`

現在オブジェクトの指定矩形内にある，不透明ピクセル全てを囲む最小の矩形を特定する．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`left`|integer\|nil|不透明ピクセル検索範囲の左端の X 座標．|
|引数 #2|`top`|integer\|nil|不透明ピクセル検索範囲の上端の Y 座標．|
|引数 #3|`right`|integer\|nil|不透明ピクセル検索範囲の右端の X 座標．|
|引数 #4|`bottom`|integer\|nil|不透明ピクセル検索範囲の下端の Y 座標．|
|戻り値 #1|`left`|integer\|nil|存在領域の左端の X 座標．全てのピクセルが完全透明の場合は `nil`.|
|戻り値 #2|`top`|integer|存在領域の上端の Y 座標．|
|戻り値 #3|`right`|integer|存在領域の右端の X 座標．|
|戻り値 #4|`bottom`|integer|存在領域の下端の Y 座標．|

- 引数の `left` が `nil` の場合はオブジェクト全体が検索の対象範囲となる．
- 全てのピクセルが完全透明だった場合は `nil` を返す．
- 座標の範囲は，左/上は inclusive (i.e. 指定値ちょうども範囲内), 右/下は exclusive (i.e. 指定値ちょうどは範囲外), ピクセル単位で左上が原点．

### `combine_aspect(zoom, aspect1, aspect2)`

2つの縦横比を組み合わせ，拡大率と縦横比の組に計算する補助関数．

|位置|名前|型|説明|
|:---|:---:|:---:|:---|
|引数 #1|`zoom`|number|拡大率．|
|引数 #2|`aspect1`|number|組み合わられる縦横比 1.|
|引数 #3|`aspect2`|number|組み合わられる縦横比 2.|
|戻り値 #1|`zoom`|number|組み合わせた結果の拡大率．|
|戻り値 #2|`aspect`|number|組み合わせた結果の縦横比．|

- 縦横比は `-1.0` から `+1.0` の範囲．

### metrics_tbl テーブル

キャッシュデータのサイズや回転に関する情報を格納するテーブル．一部 API の戻り値として得られる．

|キー|型|説明|
|:---:|:---:|:---|
|`w`|integer|キャッシュデータの横幅，ピクセル単位．|
|`h`|integer|キャッシュデータの高さ，ピクセル単位．|
|`ox`|number|位置情報の X 座標，`obj.x + obj.ox` の記録を想定．|
|`oy`|number|位置情報の Y 座標，`obj.y + obj.oy` の記録を想定．|
|`oz`|number|位置情報の Z 座標，`obj.z + obj.oz` の記録を想定．|
|`rx`|number|X 軸回転角度，度数法．`obj.rx` の記録を想定．|
|`ry`|number|Y 軸回転角度，度数法．`obj.ry` の記録を想定．|
|`rz`|number|Z 軸回転角度，度数法．`obj.rz` の記録を想定．|
|`cx`|number|回転中心の X 座標，`obj.cx` の記録を想定．|
|`cy`|number|回転中心の Y 座標，`obj.cy` の記録を想定．|
|`cz`|number|回転中心の Z 座標，`obj.cz` の記録を想定．|
|`zoom`|number|拡大率，等倍は `1.0`. `obj.zoom * obj.getvalue("zoom") / 100` の記録を想定．|
|`aspect`|number|縦横比，`-1.0` から `+1.0`. 正で縦長，負で横長．`obj.aspect` と `obj.getvalue("aspect")` を加味した値の記録を想定．|
|`alpha`|number|不透明度，完全不透明は `1.0`. `obj.alpha * obj.getvalue("alpha")` の記録を想定．|
|`init`|function|テーブル内の情報を初期値に戻す．（引数，戻り値なしで `metrics:init()` の構文で呼び出す．）|


## 改版履歴

- **v1.00** (2024-12-13)

  - 初版．


## ライセンス

このプログラムの利用・改変・再頒布等に関しては MIT ライセンスに従うものとします．

---

The MIT License (MIT)

Copyright (C) 2024 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://mit-license.org/


#  連絡・バグ報告

- GitHub: https://github.com/sigma-axis
- Twitter: https://x.com/sigma_axis
- nicovideo: https://www.nicovideo.jp/user/51492481
- Misskey.io: https://misskey.io/@sigma_axis
- Bluesky: https://bsky.app/profile/sigma-axis.bsky.social
