#
#	initially generated by c2l
#

termchars := array[] of { byte '\'', byte '=', byte ' ', byte '\t', byte '\0' };	# used in parse.c to isolate assignment attribute
shflags := "";	#  rc flag to force non-interactive mode - was -l
IWS: int = '\u0001';	#  inter-word separator in env - not used in plan 9 

# 
#  *	This file contains functions that depend on rc's syntax.  Most
#  *	of the routines extract strings observing rc's escape conventions
#  
# 
#  *	skip a token in single quotes.
#  
squote(cp: array of byte): array of byte
{
	r: int;
	n, nn: int;

	while(int cp[0]){
		(r, n, nil) = sys->byte2char(cp, 0);
		if(r == '\''){
			(r, nn, nil) = sys->byte2char(cp[n: ], 0);
			n += nn;
			if(r != '\'')
				return cp;
		}
		cp = cp[n: ];
	}
	if(-1 >= 0)	#  should never occur 
		sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), -1);
	else
		sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), mkinline);
	sys->fprint(sys->fildes(2), "missing closing '\n");
	return nil;
}

# 
#  *	search a string for characters in a pattern set
#  *	characters in quotes and variable generators are escaped
#  
charin(cp: array of byte, pat: array of byte): array of byte
{
	r: int;
	n, vargen: int;

	vargen = 0;
	while(int cp[0]){
		(r, n, nil) = sys->byte2char(cp, 0);
		case(r){
		'\'' =>	#  skip quoted string 
			cp = squote(cp[1: ]);	#  n must = 1 
			if(cp == nil)
				return nil;
		'$' =>
			if((cp[1: ])[0] == byte '{')
				vargen = 1;
		'}' =>
			if(vargen)
				vargen = 0;
			else if(libc0->strchr(pat, r) != nil)
				return cp;
		* =>
			if(vargen == 0 && libc0->strchr(pat, r) != nil)
				return cp;
		}
		cp = cp[n: ];
	}
	if(vargen){
		if(-1 >= 0)
			sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), -1);
		else
			sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), mkinline);
		sys->fprint(sys->fildes(2), "missing closing } in pattern generator\n");
	}
	return nil;
}

# 
#  *	extract an escaped token.  Possible escape chars are single-quote,
#  *	double-quote,and backslash.  Only the first is valid for rc. the
#  *	others are just inserted into the receiving buffer.
#  
expandquote(s: array of byte, r: int, b: ref Bufblock): array of byte
{
	n: int;

	if(r != '\''){
		rinsert(b, r);
		return s;
	}
	while(int s[0]){
		(r, n, nil) = sys->byte2char(s, 0);
		s = s[n: ];
		if(r == '\''){
			if(s[0] == byte '\'')
				s = s[1: ];
			else
				return s;
		}
		rinsert(b, r);
	}
	return nil;
}

# 
#  *	Input an escaped token.  Possible escape chars are single-quote,
#  *	double-quote and backslash.  Only the first is a valid escape for
#  *	rc; the others are just inserted into the receiving buffer.
#  
escapetoken(bp: ref Iobuf, buf: ref Bufblock, preserve: int, esc: int): int
{
	c, line: int;

	if(esc != '\'')
		return 1;
	line = mkinline;
	while((c = nextrune(bp, 0)) > 0){
		if(c == '\''){
			if(preserve)
				rinsert(buf, c);
			c = bp.getc();
			if(c < 0)
				break;
			if(c != '\''){
				bp.ungetc();
				return 1;
			}
		}
		rinsert(buf, c);
	}
	if(line >= 0)
		sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), line);
	else
		sys->fprint(sys->fildes(2), "mk: %s:%d: syntax error; ", libc0->ab2s(infile), mkinline);
	sys->fprint(sys->fildes(2), "missing closing %c\n", esc);
	return 0;
}

# 
#  *	copy a single-quoted string; s points to char after opening quote
#  
copysingle(s: array of byte, buf: ref Bufblock): array of byte
{
	r, n: int;

	while(int s[0]){
		(r, n, nil) = sys->byte2char(s, 0);
		s = s[n: ];
		rinsert(buf, r);
		if(r == '\'')
			break;
	}
	return s;
}

# 
#  *	check for quoted strings.  backquotes are handled here; single quotes above.
#  *	s points to char after opening quote, q.
#  
copyq(s: array of byte, q: int, buf: ref Bufblock): array of byte
{
	n: int;

	if(q == '\'')	#  copy quoted string 
		return copysingle(s, buf);
	if(q != '`')	#  not quoted 
		return s;
	while(int s[0]){	#  copy backquoted string 
		(q, n, nil) = sys->byte2char(s, 0);
		s = s[n: ];
		rinsert(buf, q);
		if(q == '}')
			break;
		if(q == '\'')
			s = copysingle(s, buf);	#  copy quoted string 
	}
	return s;
}
