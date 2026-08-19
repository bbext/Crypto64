#!/bin/sh
# Сборка подсистемы Crypto (64-битный порт, репа Crypto64) в мир BlackBox amd64.
# Мир: $BBCP64USE (по умолчанию ~/sources/bbcp64use), репо bbcp: $BBCP.
# Папка в мире — Crypto (drop-in replacement 32-битного Crypto, имена модулей те же).
# Идемпотентно: скелет Crypto/{Code,Sym} + симлинки Mod/Docu -> эта репа,
# sync .odc.txt -> .odc (OdcTextU.Batch в консоли BB64), компиляция dev0, 2 прохода
# (порядок Compile-List + добивка оставшихся: Test*, DiffieHellman, TCPServices).
set -e
BBCP="${BBCP:-$HOME/sources/bbcp}"
USE="${BBCP64USE:-$HOME/sources/bbcp64use}"
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

MODS="CryptoAosCompat CryptoAosRandom CryptoAosRealConversions CryptoAosStreams CryptoAosBigNumbers CryptoAosBIT CryptoAosClock CryptoAosCommStreams CryptoAosStrings CryptoAosDates CryptoAosFileStreams CryptoAosIP CryptoAosPipes CryptoAosTCP CryptoUtils CryptoCiphers CryptoHashes CryptoMD5 CryptoBase64 CryptoPrimes CryptoRSA CryptoAES CryptoARC4 CryptoASN1 CryptoBlowfish CryptoDES CryptoDES3 CryptoSHA256 CryptoFortuna CryptoFortunaRng CryptoHMAC CryptoIDEA CryptoKeccakF1600 CryptoKeccakSponge CryptoPKCS1 CryptoSHA1 CryptoSHA3 CryptoCAST CryptoX509 CryptoFieldElement CryptoX25519 CryptoGcm CryptoTLS CryptoTestX25519 CryptoTLSStream CryptoTestCiphers CryptoDiffieHellman CryptoTCPServices CryptoTestBigNumbers CryptoTestDH CryptoTestHashes CryptoTestHMAC CryptoTestRSA"

mkdir -p "$USE/Crypto/Code" "$USE/Crypto/Sym"
ln -sfn "$HERE/Mod" "$USE/Crypto/Mod"
ln -sfn "$HERE/Docu" "$USE/Crypto/Docu"

# sync .odc.txt -> .odc
BATCH=/tmp/odc-batch.txt	# имя захардкожено в OdcTextU.Batch
rm -f "$BATCH"
n=0
for txt in "$HERE"/Mod/*.odc.txt; do
	odc="${txt%.txt}"
	if [ ! -e "$odc" ] || [ "$txt" -nt "$odc" ]; then
		printf 'I "%s" "%s"\n' "$txt" "$odc" >> "$BATCH"
		echo "sync: $txt"
		n=$((n + 1))
	fi
done
if [ "$n" -gt 0 ]; then
	out=$(cd "$USE" && echo 'OdcTextU.Batch' | BB_CONSOLE=1 BB_STANDARD_DIR="$USE" \
		timeout -k 5 300 "$BBCP/Dev/Rsrc/bbrun64" --console 2>&1)
	done_n=$(printf '%s\n' "$out" | grep -c '^Done! res:  0$' || true)
	rm -f "$BATCH"
	[ "$done_n" = "$n" ] || { echo "sync FAILED ($done_n of $n)" >&2; exit 1; }
fi

# компиляция. Как go64.sh:
# - прячем 32-битные Sym в bbcp (иначе компилятор подхватывает их через
#   fallback и получает чужие fingerprint'ы — runtime "inconsistently imported",
#   кейс: CryptoFortunaRng vs DevHeapSpy);
# - прячем ТОЛЬКО $USE/Dev/Code (64-битные DevCP*.ocf ломают dev0),
#   Dev/Sym оставляем — импорты DevHeapSpy/... должны резолвиться в 64-битные sym.
for d in "$BBCP"/*/Sym; do
	[ -d "$d" ] && mv "$d" "${d}32stash"
done
restore_sym() {
	for d in "$BBCP"/*/Sym32stash; do
		[ -d "$d" ] && mv "$d" "${d%32stash}"
	done
}
STASH="$USE/.dev-stash-crypto"
[ -d "$USE/Dev/Code" ] && { mkdir -p "$STASH"; mv "$USE/Dev/Code" "$STASH/Code"; }
cleanup() { [ -d "$STASH/Code" ] && mv "$STASH/Code" "$USE/Dev/Code"; rmdir "$STASH" 2>/dev/null; restore_sym; }
trap cleanup EXIT
trap 'exit 1' INT TERM PIPE
cd "$USE"
printf '%s\n' $MODS > /tmp/compile1.txt
# 2 прохода: порядок списка не гарантирует готовые sym для всех импортов.
# Логи полные (не tail): старый ocf может маскировать свежие ошибки компиляции.
echo 'DevOnce.Go64' | "$BBCP/run-dev0" > /tmp/crypto-pass1.log 2>&1
echo 'DevOnce.Go64' | "$BBCP/run-dev0" > /tmp/crypto-pass2.log 2>&1
grep -E 'compiling|err = |ERROR' /tmp/crypto-pass2.log | tail -30
if grep -qE 'err = |ERROR' /tmp/crypto-pass2.log; then
	echo "build: compile errors (см. /tmp/crypto-pass2.log)" >&2
	exit 1
fi
fail=0
for m in $MODS; do
	f="$USE/Crypto/Code/${m#Crypto}.ocf"
	[ -f "$f" ] || { echo "build: $m — ocf не найден" >&2; fail=1; }
done
[ $fail -eq 0 ] && echo "build: Crypto ok"
