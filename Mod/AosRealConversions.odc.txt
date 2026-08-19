MODULE CryptoAosRealConversions;  (* GF *)

	IMPORT SYSTEM, AO := CryptoAosCompat;

	TYPE
		PeekNext* = POINTER TO ABSTRACT RECORD END;

	VAR
		H, L: AO.SIGNED16;

		PROCEDURE (SELF : PeekNext) Do*(): SHORTCHAR, NEW, ABSTRACT;

	PROCEDURE IsDigit (ch : SHORTCHAR): BOOLEAN;

	BEGIN
		RETURN (ch >= "0") & (ch <= "9")
	END IsDigit;


	PROCEDURE RealL (h, l : AO.SIGNED32): AO.FLOAT64;
		VAR
			x: AO.FLOAT64;


	BEGIN
		SYSTEM.PUT(SYSTEM.ADR(x) + H, h);
		SYSTEM.PUT(SYSTEM.ADR(x) + L, l);
		RETURN x
	END RealL;

	PROCEDURE Ten (e : AO.SIGNED32): AO.FLOAT64;
		VAR
			r: AO.FLOAT64;


	BEGIN
		IF e < (-307) THEN
			RETURN (*WARN CONV CAST*)LONG(0)
		ELSIF 308 < e THEN
			RETURN RealL(2146435072, 0)
		END;
		r := (*WARN CONV CAST*)LONG(1);
		WHILE (e > 0) DO
			r := r * 10;
			DEC(e)
		END;
		WHILE (e < 0) DO
			r := r / 10;
			INC(e)
		END;
		RETURN r
	END Ten;

	PROCEDURE ScanReal* (ch : SHORTCHAR; next : PeekNext; VAR r : AO.FLOAT64): BOOLEAN;
		VAR
			neg, negE: BOOLEAN;

		VAR
			y: AO.FLOAT64;
			e: AO.SIGNED16;

		PROCEDURE ScanFractionalPart ;
			VAR
				g: AO.FLOAT64;

		BEGIN
			g := 1;
			WHILE ("0" <= ch) & (ch <= "9") DO
				g := g / 10;
				y := y + g * (ORD(ch) - ORD("0"));
				ch := next.Do()
			END
		END ScanFractionalPart;

	BEGIN
		negE := FALSE;
		neg := FALSE;
		y := 0;
		WHILE (ch = " ") DO
			ch := next.Do()
		END;
		IF ch = "-" THEN
			neg := TRUE;
			ch := next.Do()
		ELSIF ch = "+" THEN
			ch := next.Do()
		END;
		IF ch # "." THEN
			IF ~IsDigit(ch) THEN
				RETURN FALSE
			END;
			WHILE (ch = "0") DO
				ch := next.Do()
			END;
			WHILE ("0" <= ch) & (ch <= "9") DO
				y := y * 10 + (ORD(ch) - ORD("0"));
				ch := next.Do()
			END;
			IF ch = "." THEN
				ch := next.Do();
				ScanFractionalPart
			END
		ELSE
			ch := next.Do();
			IF IsDigit(ch) THEN
				ScanFractionalPart
			ELSE
				RETURN FALSE
			END
		END;
		IF (ch = "d") OR (ch = "D") OR (ch = "e") OR (ch = "E") THEN
			ch := next.Do();
			IF ch = "-" THEN
				negE := TRUE;
				ch := next.Do()
			ELSIF ch = "+" THEN
				ch := next.Do()
			END;
			IF ~IsDigit(ch) THEN
				RETURN FALSE
			END;
			WHILE (ch = "0") DO
				ch := next.Do()
			END;
			e := 0;
			WHILE ("0" <= ch) & (ch <= "9") DO
				e := SHORT(e * 10 + (ORD(ch) - ORD("0")));
				ch := next.Do()
			END;
			IF negE THEN
				y := y / Ten((*WARN CONV CAST*)LONG(e))
			ELSE
				y := y * Ten((*WARN CONV CAST*)LONG(e))
			END
		END;
		IF neg THEN
			y := (-y)
		END;
		r := y;
		RETURN TRUE
	END ScanReal;

	PROCEDURE StringToReal* (IN s : ARRAY OF SHORTCHAR; VAR r : AO.FLOAT64): BOOLEAN;
		VAR
			neg, negE: BOOLEAN;

		VAR
			ch: SHORTCHAR;
			p: AO.SIZE;
			y: AO.FLOAT64;
			e: AO.SIGNED16;

		PROCEDURE ScanFractionalPart ;
			VAR
				g: AO.FLOAT64;

		BEGIN
			g := 1;
			WHILE ("0" <= ch) & (ch <= "9") DO
				g := g / 10;
				y := y + g * (ORD(ch) - ORD("0"));
				INC(p);
				ch := s[p]
			END
		END ScanFractionalPart;

	BEGIN
		negE := FALSE;
		neg := FALSE;
		ch := s[0];
		p := 0;
		y := 0;
		WHILE (ch = " ") DO
			INC(p);
			ch := s[p]
		END;
		IF ch = "-" THEN
			neg := TRUE;
			INC(p);
			ch := s[p]
		ELSIF ch = "+" THEN
			INC(p);
			ch := s[p]
		END;
		IF ch # "." THEN
			IF ~IsDigit(ch) THEN
				RETURN FALSE
			END;
			WHILE (ch = "0") DO
				INC(p);
				ch := s[p]
			END;
			WHILE ("0" <= ch) & (ch <= "9") DO
				y := y * 10 + (ORD(ch) - ORD("0"));
				INC(p);
				ch := s[p]
			END;
			IF ch = "." THEN
				INC(p);
				ch := s[p];
				ScanFractionalPart
			END
		ELSE
			INC(p);
			ch := s[p];
			IF IsDigit(ch) THEN
				ScanFractionalPart
			ELSE
				RETURN FALSE
			END
		END;
		IF (ch = "d") OR (ch = "D") OR (ch = "e") OR (ch = "E") THEN
			INC(p);
			ch := s[p];
			IF ch = "-" THEN
				negE := TRUE;
				INC(p);
				ch := s[p]
			ELSIF ch = "+" THEN
				INC(p);
				ch := s[p]
			END;
			IF ~IsDigit(ch) THEN
				RETURN FALSE
			END;
			WHILE (ch = "0") DO
				INC(p);
				ch := s[p]
			END;
			e := 0;
			WHILE ("0" <= ch) & (ch <= "9") DO
				e := SHORT(e * 10 + (ORD(ch) - ORD("0")));
				INC(p);
				ch := s[p]
			END;
			IF negE THEN
				y := y / Ten((*WARN CONV CAST*)LONG(e))
			ELSE
				y := y * Ten((*WARN CONV CAST*)LONG(e))
			END
		END;
		WHILE (ch = " ") DO
			INC(p);
			ch := s[p]
		END;
		IF (ch # 0X) THEN
			RETURN FALSE
		END;
		IF neg THEN
			y := (-y)
		END;
		r := y;
		RETURN TRUE
	END StringToReal;

	PROCEDURE ExpoL (x : AO.FLOAT64): AO.SIGNED32;
		VAR
			i: AO.SIGNED32;


	BEGIN
		SYSTEM.GET(SYSTEM.ADR(x) + H, i);
		RETURN ASH(i, (-20)) MOD 2048
	END ExpoL;

	PROCEDURE NaNCodeL (x : AO.FLOAT64; VAR h, l : AO.SIGNED32);

	BEGIN
		SYSTEM.GET(SYSTEM.ADR(x) + H, h);
		SYSTEM.GET(SYSTEM.ADR(x) + L, l);
		IF ASH(h, (-20)) MOD 2048 = 2047 THEN
			h := h MOD 100000H
		ELSE
			h := (-1);
			l := (-1)
		END
	END NaNCodeL;

	PROCEDURE RealToString* (x : AO.FLOAT64; n : INTEGER; VAR buf : ARRAY OF SHORTCHAR);
		VAR
			e, h, l, i, pos: AO.SIGNED32;
			z: AO.FLOAT64;
			d: ARRAY 16 OF SHORTCHAR;
			m: INTEGER;


		PROCEDURE Char (c : SHORTCHAR);

		BEGIN
			buf[pos] := c;
			INC(pos)
		END Char;

		PROCEDURE String (IN s : ARRAY OF SHORTCHAR);
			VAR
				i: AO.SIGNED32;


		BEGIN
			i := 0;
			WHILE s[i] # 0X DO
				Char(s[i]);
				INC(i)
			END
		END String;

	BEGIN
		pos := 0;
		e := ExpoL(x);
		IF e = 2047 THEN
			NaNCodeL(x, h, l);
			IF (h # 0) OR (l # 0) THEN
				String("NaN")
			ELSIF x < 0 THEN
				String("-INF")
			ELSE
				String("+INF")
			END
		ELSE
			IF (e # 0) & (x < 0) THEN
				Char("-");
				x := (-x)
			END;
			IF e = 0 THEN
				h := 0;
				l := 0
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;
				z := Ten(e + 1);
				IF x >= z THEN
					x := x / z;
					INC(e)
				ELSE
					x := x * Ten((-e))
				END;
				IF x >= 10 THEN
					x := x * Ten((-1)) + 0.5E0 / Ten(15);
					INC(e)
				ELSE
					x := x + 0.5E0 / Ten(15);
					IF x >= 10 THEN
						x := x * Ten((-1));
						INC(e)
					END
				END;
				x := x * Ten(7);
				h := SHORT(ENTIER(x));
				x := (x - h) * Ten(8);
				l := SHORT(ENTIER(x))
			END;
			i := 15;
			WHILE i > 7 DO
				d[i] := (*WARN CONV CAST*)SHORT(CHR(l MOD 10 + ORD("0")));
				l := l DIV 10;
				DEC(i)
			END;
			WHILE i >= 0 DO
				d[i] := (*WARN CONV CAST*)SHORT(CHR(h MOD 10 + ORD("0")));
				h := h DIV 10;
				DEC(i)
			END;
			Char(d[0]);
			Char(".");
			m := 15;
			WHILE (m > 0) & (d[m] = '0') DO
				DEC(m)
			END;
			FOR i := 1 TO m DO
				Char(d[i])
			END;
			IF e # 0 THEN
				IF e < 0 THEN
					String("E-");
					e := (-e)
				ELSE
					String("E+")
				END;
				IF e >= 100 THEN
					Char((*WARN CONV CAST*)SHORT(CHR(e DIV 100 + ORD("0"))))
				END;
				IF e >= 10 THEN
					Char((*WARN CONV CAST*)SHORT(CHR(e MOD 100 DIV 10 + ORD("0"))))
				END;
				Char((*WARN CONV CAST*)SHORT(CHR(e MOD 10 + ORD("0"))))
			END
		END;
		buf[pos] := 0X;
		INC(n);
		IF n > pos THEN
			WHILE (pos >= 0) DO
				buf[n] := buf[pos];
				DEC(pos);
				DEC(n)
			END;
			WHILE (n >= 0) DO
				buf[n] := " ";
				DEC(n)
			END
		END
	END RealToString;

	PROCEDURE RealToStringFix* (x : AO.FLOAT64; n, f, D : INTEGER; VAR buf : ARRAY OF SHORTCHAR);
		VAR
			e, h, l, i, pos: AO.SIGNED32;
			r, z: AO.FLOAT64;
			d: ARRAY 16 OF SHORTCHAR;
			s: SHORTCHAR;
			dot: BOOLEAN;


		PROCEDURE Char (c : SHORTCHAR);

		BEGIN
			buf[pos] := c;
			INC(pos)
		END Char;

		PROCEDURE String (IN s : ARRAY OF SHORTCHAR);
			VAR
				i: AO.SIGNED32;
				ch: SHORTCHAR;


		BEGIN
			ch := s[0];
			i := 1;
			WHILE ch # 0X DO
				Char(ch);
				ch := s[i];
				INC(i)
			END
		END String;

	BEGIN
		pos := 0;
		e := ExpoL(x);
		IF (e = 2047) OR (ABS(D) > 308) THEN
			WHILE n > 5 DO
				Char(" ");
				DEC(n)
			END;
			NaNCodeL(x, h, l);
			IF (h # 0) OR (l # 0) THEN
				String("  NaN")
			ELSIF x < 0 THEN
				String(" -INF")
			ELSE
				String("  INF")
			END
		ELSE
			IF D = 0 THEN
				IF f = 0 THEN
					dot := FALSE;
					DEC(n, 1)
				ELSE
					dot := TRUE;
					DEC(n, 2)
				END
			ELSE
				dot := TRUE;
				DEC(n, 7)
			END;
			IF n < 2 THEN
				n := 2
			END;
			IF f < 0 THEN
				f := 0
			END;
			IF n < f + 2 THEN
				n := f + 2
			END;
			DEC(n, f);
			IF (e # 0) & (x < 0) THEN
				s := "-";
				x := (-x)
			ELSE
				s := " "
			END;
			IF e = 0 THEN
				h := 0;
				l := 0;
				DEC(e, D - 1)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;
				z := Ten(e + 1);
				IF x >= z THEN
					x := x / z;
					INC(e)
				ELSE
					x := x * Ten((-e))
				END;
				DEC(e, D - 1);
				i := (-(e + f));
				IF i <= 0 THEN
					r := 5 * Ten(i)
				ELSE
					r := (*WARN CONV CAST*)LONG(0)
				END;
				IF x >= 10 THEN
					x := x * Ten((-1)) + r;
					INC(e)
				ELSE
					x := x + r;
					IF x >= 10 THEN
						x := x * Ten((-1));
						INC(e)
					END
				END;
				x := x * Ten(7);
				h := SHORT(ENTIER(x));
				x := (x - h) * Ten(8);
				l := SHORT(ENTIER(x))
			END;
			i := 15;
			WHILE i > 7 DO
				d[i] := (*WARN CONV CAST*)SHORT(CHR(l MOD 10 + ORD("0")));
				l := l DIV 10;
				DEC(i)
			END;
			WHILE i >= 0 DO
				d[i] := (*WARN CONV CAST*)SHORT(CHR(h MOD 10 + ORD("0")));
				h := h DIV 10;
				DEC(i)
			END;
			IF n <= e THEN
				n := e + 1
			END;
			IF e > 0 THEN
				WHILE n > e DO
					Char(" ");
					DEC(n)
				END;
				Char(s);
				e := 0;
				WHILE n > 0 DO
					DEC(n);
					IF e < 16 THEN
						Char(d[e]);
						INC(e)
					ELSE
						Char("0")
					END
				END;
				IF dot THEN
					Char(".")
				END
			ELSE
				WHILE n > 1 DO
					Char(" ");
					DEC(n)
				END;
				Char(s);
				Char("0");
				IF dot THEN
					Char(".")
				END;
				WHILE (0 < f) & (e < 0) DO
					Char("0");
					DEC(f);
					INC(e)
				END
			END;
			WHILE f > 0 DO
				DEC(f);
				IF e < 16 THEN
					Char(d[e]);
					INC(e)
				ELSE
					Char("0")
				END
			END;
			IF D # 0 THEN
				IF D < 0 THEN
					String("E-");
					D := (-D)
				ELSE
					String("E+")
				END;
				Char((*WARN CONV CAST*)SHORT(CHR(D DIV 100 + ORD("0"))));
				D := D MOD 100;
				Char((*WARN CONV CAST*)SHORT(CHR(D DIV 10 + ORD("0"))));
				Char((*WARN CONV CAST*)SHORT(CHR(D MOD 10 + ORD("0"))))
			END
		END;
		Char(0X)
	END RealToStringFix;

	PROCEDURE InitHL ;
		VAR
			i: AO.ADDRESS;
			dmy: AO.SIGNED16;
			littleEndian: BOOLEAN;


	BEGIN
		dmy := (*WARN CONV CAST*)SHORT(1);
		i := SYSTEM.ADR(dmy);
		SYSTEM.GET(i, littleEndian);
		IF littleEndian THEN
			H := (*WARN CONV CAST*)SHORT(4);
			L := (*WARN CONV CAST*)SHORT(0)
		ELSE
			H := (*WARN CONV CAST*)SHORT(0);
			L := (*WARN CONV CAST*)SHORT(4)
		END
	END InitHL;

BEGIN
	InitHL
END CryptoAosRealConversions.
