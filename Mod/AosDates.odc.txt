MODULE CryptoAosDates;

	(** AUTHOR "be, tf, staubesv"; PURPOSE "Date and time functions"; *)

(** Oberon date & time format:
		time: bits 16-12: hours
					11-6: minutes
					5-0: seconds

		date: 30-9: count of years from 1900
					8-5: month of year
					4-0: day of month
*)

(*	Problem of leap seconds is handled as in POSIX:
		http://www.eecis.udel.edu/~mills/leap.html
		http://en.wikipedia.org/wiki/Leap_second
*)

	IMPORT Clock:= CryptoAosClock, Strings := CryptoAosStrings, AO := CryptoAosCompat;
	TYPE
		DateTime* = RECORD
			year*, month*, day*, hour*, minute*, second* : AO.SIGNED32
		END;
	VAR
		Months: ARRAY 12 OF ARRAY 10 OF SHORTCHAR;
		Days: ARRAY 7 OF ARRAY 10 OF SHORTCHAR;
		NoDays: ARRAY 12 OF AO.SIGNED16;
		ZeroDateUnix, ZeroDateRFC868, ZeroDateNTP: DateTime;
		DateFormat, TimeFormat: ARRAY 32 OF SHORTCHAR;

	PROCEDURE LeapYear* (year : AO.SIGNED32): BOOLEAN;
	BEGIN
		RETURN (year > 0) & (year MOD 4 = 0) & (~(year MOD 100 = 0) OR (year MOD 400 = 0))
	END LeapYear;

	PROCEDURE NofDays* (year, month : AO.SIGNED32): AO.SIGNED32;
	BEGIN
		DEC(month);
		ASSERT((month >= 0) & (month < 12));
		IF (month = 1) & LeapYear(year) THEN
			RETURN NoDays[1] + 1
		ELSE
			RETURN (*WARN CONV CAST*)LONG(NoDays[month])
		END
	END NofDays;

	PROCEDURE ValidDateTime* (dt : DateTime): BOOLEAN;
	BEGIN
		RETURN (dt.year > 0) & (dt.month > 0) & (dt.month <= 12) & (dt.day > 0) & (dt.day <= NofDays(dt.year, dt.month)) & (dt.hour >= 0) & (dt.hour < 24) & (dt.minute >= 0) & (dt.minute < 60) & (dt.second >= 0) & (dt.second < 60)
	END ValidDateTime;

	PROCEDURE OberonToDateTime* (Date, Time : AO.SIGNED32): POINTER TO DateTime;
		VAR dt: POINTER TO DateTime;
	BEGIN
		NEW(dt);
		dt.second := Time MOD 64;
		Time := Time DIV 64;
		dt.minute := Time MOD 64;
		Time := Time DIV 64;
		dt.hour := Time MOD 24;
		dt.day := Date MOD 32;
		Date := Date DIV 32;
		dt.month := Date MOD 16;
		Date := Date DIV 16;
		dt.year := 1900 + Date;
		RETURN dt
	END OberonToDateTime;

	PROCEDURE DateTimeToOberon* (dt : DateTime; VAR date, time : AO.SIGNED32);
	BEGIN
		ASSERT(ValidDateTime(dt));
		date := (dt.year - 1900) * 512 + dt.month * 32 + dt.day;
		time := dt.hour * 4096 + dt.minute * 64 + dt.second
	END DateTimeToOberon;

	PROCEDURE Now* (): POINTER TO DateTime;
		VAR d, t: AO.SIGNED32;
	BEGIN
		Clock.Get(t, d);
		RETURN OberonToDateTime(d, t)
	END Now;

	PROCEDURE WeekDate* (Date : DateTime; VAR year, week, weekday : AO.SIGNED32);
		VAR doy, i, yy, c, g, jan1: AO.SIGNED32; leap: BOOLEAN;
	BEGIN
		IF ValidDateTime(Date) THEN
			leap := LeapYear(Date.year);
			doy := Date.day;
			i := 0;
			WHILE (i < Date.month - 1) DO
				doy := doy + NoDays[i];
				INC(i)
			END;
			IF leap & (Date.month > 2) THEN
				INC(doy)
			END;
			yy := (Date.year - 1) MOD 100;
			c := (Date.year - 1) - yy;
			g := yy + yy DIV 4;
			jan1 := 1 + (((((c DIV 100) MOD 4) * 5) + g) MOD 7);
			weekday := 1 + (((doy + (jan1 - 1)) - 1) MOD 7);
			IF (doy <= (8 - jan1)) & (jan1 > 4) THEN
				year := Date.year - 1;
				IF (jan1 = 5) OR ((jan1 = 6) & LeapYear(year)) THEN
					week := 53
				ELSE
					week := 52
				END
			ELSE
				IF leap THEN
					i := 366
				ELSE
					i := 365
				END;
				IF ((i - doy) < (4 - weekday)) THEN
					year := Date.year + 1;
					week := 1
				ELSE
					year := Date.year;
					i := doy + (7 - weekday) + (jan1 - 1);
					week := i DIV 7;
					IF (jan1 > 4) THEN
						DEC(week)
					END
				END
			END
		ELSE
			year := (-1);
			week := (-1);
			weekday := (-1)
		END
	END WeekDate;

	PROCEDURE Equal* (t1, t2 : DateTime): BOOLEAN;
	BEGIN
		RETURN (t1.second = t2.second) & (t1.minute = t2.minute) & (t1.hour = t2.hour) & (t1.day = t2.day) & (t1.month = t2.month) & (t1.year = t2.year)
	END Equal;

	PROCEDURE CompareDateTime* (t1, t2 : DateTime): AO.SIGNED32;
		VAR result: AO.SIGNED32;

		PROCEDURE Compare (t1, t2 : AO.SIGNED32): AO.SIGNED32;
			VAR result: AO.SIGNED32;
		BEGIN
			IF (t1 < t2) THEN
				result := (-1)
			ELSIF (t1 > t2) THEN
				result := 1
			ELSE
				result := 0
			END;
			RETURN result
		END Compare;

	BEGIN
		ASSERT(ValidDateTime(t1) & (ValidDateTime(t2)));
		result := Compare(t1.year, t2.year);
		IF (result = 0) THEN
			result := Compare(t1.month, t2.month);
			IF (result = 0) THEN
				result := Compare(t1.day, t2.day);
				IF (result = 0) THEN
					result := Compare(t1.hour, t2.hour);
					IF (result = 0) THEN
						result := Compare(t1.minute, t2.minute);
						IF (result = 0) THEN
							result := Compare(t1.second, t2.second)
						END
					END
				END
			END
		END;
		RETURN result
	END CompareDateTime;

	PROCEDURE TimeDifference* (t1, t2 : DateTime; VAR days, hours, minutes, seconds : AO.SIGNED32);
		CONST
			SecondsPerMinute = 60;
			SecondsPerHour = 3600;
			SecondsPerDay = 86400;
		VAR
			start, end: DateTime;
			year, month, second: AO.SIGNED32;
	BEGIN
		IF (CompareDateTime(t1, t2) = (-1)) THEN
			start := t1;
			end := t2
		ELSE
			start := t2;
			end := t1
		END;
		IF (start.year = end.year) & (start.month = end.month) & (start.day = end.day) THEN
			second := end.second - start.second + (end.minute - start.minute) * SecondsPerMinute + (end.hour - start.hour) * SecondsPerHour;
			days := 0
		ELSE
			second := SecondsPerDay - start.second - start.minute * SecondsPerMinute - start.hour * SecondsPerHour;
			IF (start.year = end.year) & (start.month = end.month) THEN
				days := (end.day - start.day) - 1
			ELSE
				days := NofDays(start.year, start.month) - start.day;
				IF (start.year = end.year) THEN
					FOR month := start.month + 1 TO end.month - 1 DO
						days := days + NofDays(start.year, month)
					END
				ELSE
					FOR month := start.month + 1 TO 12 DO
						days := days + NofDays(start.year, month)
					END;
					FOR year := start.year + 1 TO end.year - 1 DO
						IF LeapYear(year) THEN
							days := days + 366
						ELSE
							days := days + 365
						END
					END;
					FOR month := 1 TO end.month - 1 DO
						days := days + NofDays(end.year, month)
					END
				END;
				days := days + end.day - 1
			END;
			second := second + end.second + end.minute * SecondsPerMinute + end.hour * SecondsPerHour
		END;
		days := days + (second DIV SecondsPerDay);
		second := second MOD SecondsPerDay;
		hours := second DIV SecondsPerHour;
		second := second MOD SecondsPerHour;
		minutes := second DIV SecondsPerMinute;
		second := second MOD SecondsPerMinute;
		seconds := second
	END TimeDifference;

	PROCEDURE AddYears* (VAR dt : DateTime; years : AO.SIGNED32);
	BEGIN
		ASSERT(ValidDateTime(dt));
		dt.year := dt.year + years;
		ASSERT(ValidDateTime(dt))
	END AddYears;

	PROCEDURE AddMonths* (VAR dt : DateTime; months : AO.SIGNED32);
		VAR years: AO.SIGNED32;
	BEGIN
		ASSERT(ValidDateTime(dt));
		years := months DIV 12;
		dt.month := dt.month + (months MOD 12);
		IF dt.month > 12 THEN
			dt.month := dt.month - 12;
			INC(years)
		ELSIF dt.month < 1 THEN
			dt.month := dt.month + 12;
			DEC(years)
		END;
		IF years # 0 THEN
			AddYears(dt, years)
		END;
		ASSERT(ValidDateTime(dt))
	END AddMonths;

	PROCEDURE AddDays* (VAR dt : DateTime; days : AO.SIGNED32);
		VAR nofDaysLeft: AO.SIGNED32;
	BEGIN
		ASSERT(ValidDateTime(dt));
		IF (days > 0) THEN
			WHILE (days > 0) DO
				nofDaysLeft := NofDays(dt.year, dt.month) - dt.day;
				IF (days > nofDaysLeft) THEN
					dt.day := 1;
					AddMonths(dt, 1);
					days := days - nofDaysLeft - 1
				ELSE
					dt.day := dt.day + days;
					days := 0
				END
			END
		ELSIF (days < 0) THEN
			days := (-days);
			WHILE (days > 0) DO
				nofDaysLeft := dt.day - 1;
				IF (days > nofDaysLeft) THEN
					dt.day := 1;
					AddMonths(dt, (-1));
					dt.day := NofDays(dt.year, dt.month);
					days := days - nofDaysLeft - 1
				ELSE
					dt.day := dt.day - days;
					days := 0
				END
			END
		END;
		ASSERT(ValidDateTime(dt))
	END AddDays;

	PROCEDURE AddHours* (VAR dt : DateTime; hours : AO.SIGNED32);
		VAR days: AO.SIGNED32;
	BEGIN
		ASSERT(ValidDateTime(dt));
		dt.hour := dt.hour + hours;
		days := dt.hour DIV 24;
		dt.hour := dt.hour MOD 24;
		IF (dt.hour < 0) THEN
			dt.hour := dt.hour + 24;
			DEC(days)
		END;
		IF (days # 0) THEN
			AddDays(dt, days)
		END;
		ASSERT(ValidDateTime(dt))
	END AddHours;

	PROCEDURE AddMinutes* (VAR dt : DateTime; minutes : AO.SIGNED32);
		VAR hours: AO.SIGNED32;
	BEGIN
		ASSERT(ValidDateTime(dt));
		dt.minute := dt.minute + minutes;
		hours := dt.minute DIV 60;
		dt.minute := dt.minute MOD 60;
		IF (dt.minute < 0) THEN
			dt.minute := dt.minute + 60;
			DEC(hours)
		END;
		IF (hours # 0) THEN
			AddHours(dt, hours)
		END;
		ASSERT(ValidDateTime(dt))
	END AddMinutes;

	PROCEDURE AddSeconds* (VAR dt : DateTime; seconds : AO.SIGNED32);
		VAR minutes: AO.SIGNED32;

	BEGIN
		ASSERT(ValidDateTime(dt));
		dt.second := dt.second + seconds;
		minutes := dt.second DIV 60;
		dt.second := dt.second MOD 60;
		IF (dt.second < 0) THEN
			dt.second := dt.second + 60;
			DEC(minutes)
		END;
		IF (minutes # 0) THEN
			AddMinutes(dt, minutes)
		END;
		ASSERT(ValidDateTime(dt))
	END AddSeconds;

	PROCEDURE FormatDateTime* (IN format : ARRAY OF SHORTCHAR; dt : DateTime; VAR result : ARRAY OF SHORTCHAR);
		VAR
			i, k, l, len, n: AO.SIZE;
			m, y, w, dw: AO.SIGNED32;


		PROCEDURE IntToStr (v : AO.SIGNED32; len : AO.SIZE; VAR s : ARRAY OF SHORTCHAR; VAR pos : AO.SIZE);
			VAR i: AO.SIZE;

		BEGIN
			FOR i := 1 TO len DO
				s[pos + len - i] := (*WARN CONV CAST*)SHORT(CHR(ORD("0") + v MOD 10));
				v := v DIV 10
			END;
			INC(pos, len)
		END IntToStr;

	BEGIN
		k := 0;
		IF ValidDateTime(dt) THEN
			i := 0;
			WHILE (format[i] # 0X) DO
				n := 1;
				WHILE (format[i + n] = format[i]) DO
					INC(n)
				END;
				len := n;
				CASE format[i] OF
					"w" :			   WeekDate(dt, y, w, dw);
				DEC(dw);
				IF (len >= 4) THEN
					len := 10
				END;
				l := 0;
				WHILE (l < len) & (Days[dw, l] # 0X) DO
					result[k] := Days[dw, l];
					INC(k);
					INC(l)
				END
				|       "y" :			   IntToStr(dt.year, n, result, k)
				|       "m" :			   IF (n >= 3) THEN
					m := dt.month - 1;
					ASSERT((m >= 0) & (m < 12));
					IF (len > 3) THEN
						len := 12
					END;
					l := 0;
					WHILE (l < len) & (Months[m, l] # 0X) DO
						result[k] := Months[m, l];
						INC(k);
						INC(l)
					END
				ELSE
					IF (len = 1) & (dt.month > 9) THEN
						len := 2
					END;
					IntToStr(dt.month, len, result, k)
				END
				|       "d" :			   IF (len = 1) & (dt.day > 9) THEN
					len := 2
				END;
				IntToStr(dt.day, len, result, k)
				|       "h" :			   IF (len = 1) & (dt.hour > 9) THEN
					len := 2
				END;
				IntToStr(dt.hour, len, result, k)
				|       "n" :			   IF (len = 1) & (dt.minute > 9) THEN
					len := 2
				END;
				IntToStr(dt.minute, len, result, k)
				|       "s" :			   IF (len = 1) & (dt.second > 9) THEN
					len := 2
				END;
				IntToStr(dt.second, len, result, k)
				ELSE
					result[k] := format[i];
					INC(k);
					n := 1
				END;
				INC(i, n)
			END
		END;
		result[k] := 0X
	END FormatDateTime;

	PROCEDURE TimeToStr* (time : DateTime; VAR s : ARRAY OF SHORTCHAR);
	BEGIN
		FormatDateTime(TimeFormat, time, s)
	END TimeToStr;

	PROCEDURE StrToTime* (IN str : ARRAY OF SHORTCHAR; VAR dt : DateTime);
		VAR i: AO.SIZE;
	BEGIN
		i := 0;
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.hour, i);
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.minute, i);
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.second, i);
		ASSERT(ValidDateTime(dt))
	END StrToTime;

	PROCEDURE DateToStr* (date : DateTime; VAR s : ARRAY OF SHORTCHAR);
	BEGIN
		FormatDateTime(DateFormat, date, s)
	END DateToStr;

	PROCEDURE StrToDate* (IN str : ARRAY OF SHORTCHAR; VAR dt : DateTime);
		VAR i: AO.SIZE;
	BEGIN
		i := 0;
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.day, i);
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.month, i);
		WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO
			INC(i)
		END;
		Strings.StrToIntPos(str, dt.year, i);
		ASSERT(ValidDateTime(dt))
	END StrToDate;

BEGIN
	DateFormat := "dd.mmm.yyyy";
	TimeFormat := "hh:nn:ss";
	Months[0] := "January";
	Months[1] := "February";
	Months[2] := "March";
	Months[3] := "April";
	Months[4] := "May";
	Months[5] := "June";
	Months[6] := "July";
	Months[7] := "August";
	Months[8] := "September";
	Months[9] := "October";
	Months[10] := "November";
	Months[11] := "December";
	Days[0] := "Monday";
	Days[1] := "Tuesday";
	Days[2] := "Wednesday";
	Days[3] := "Thursday";
	Days[4] := "Friday";
	Days[5] := "Saturday";
	Days[6] := "Sunday";
	NoDays[0] := (*WARN CONV CAST*)SHORT(31);
	NoDays[1] := (*WARN CONV CAST*)SHORT(28);
	NoDays[2] := (*WARN CONV CAST*)SHORT(31);
	NoDays[3] := (*WARN CONV CAST*)SHORT(30);
	NoDays[4] := (*WARN CONV CAST*)SHORT(31);
	NoDays[5] := (*WARN CONV CAST*)SHORT(30);
	NoDays[6] := (*WARN CONV CAST*)SHORT(31);
	NoDays[7] := (*WARN CONV CAST*)SHORT(31);
	NoDays[8] := (*WARN CONV CAST*)SHORT(30);
	NoDays[9] := (*WARN CONV CAST*)SHORT(31);
	NoDays[10] := (*WARN CONV CAST*)SHORT(30);
	NoDays[11] := (*WARN CONV CAST*)SHORT(31);
		
	ZeroDateUnix.year := 1970;
	ZeroDateUnix.month := 1;
	ZeroDateUnix.day := 1;
	
	ZeroDateRFC868.year := 1900;
	ZeroDateRFC868.month := 1;
	ZeroDateRFC868.day := 1;
	ZeroDateNTP := ZeroDateRFC868
END CryptoAosDates.
