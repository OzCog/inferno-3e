implement Pi;

include "sys.m";
	sys: Sys;
include "draw.m";
include "math.m";
	math: Math;
	log: import math;
include "daytime.m";
	daytime: Daytime;

LMPBASE: con 8;
RMPBASE: con 10000;
MPBASE: con RMPBASE*RMPBASE;	# TBS 2^30 + ops become masks and shifts

LBASE: con 3;	# 4
BASE: con 1000;	# 10000

stderr: ref Sys->FD;

# spawn process for each series ?

Mp: type array of int;

Pi: module
{
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	math = load Math Math->PATH;
	daytime = load Daytime Daytime->PATH;

	stderr = sys->fildes(2);
	dp := 1000;
	argv = tl argv;
	if(argv != nil){
		if(tl argv != nil){
			picmp(hd argv, hd tl argv);
			exit;
		}
		dp = int hd argv;
	}
	if(dp <= 0)
		exit;
	t1 := daytime->now();
	p2 := pi2(dp+1);
	t2 := daytime->now();
	prpi(p2);
	p1 := pi1(dp+1);
	t3 := daytime->now();
	# sys->print("%d %d\n", t2-t1, t3-t2);
	if(p1 == nil && p2 == nil)
		fatal("too many dp: reduce dp or source base");
	else if(p1 == nil)
		p1 = p2;
	else if(p2 == nil)
		p2 = p1;
	n1 := len p1;
	n2 := len p2;
	if(n1 != n2)
		fatal(sys->sprint("lens differ %d %d", n1, n2));
	f := array[10] of { * => 0 };
	for(i := 0; i < n1; i++){
		if(p1[i] != p2[i])
			fatal(sys->sprint("arrays differ %d/%d: %d %d", i, n1, p1[i], p2[i]));
		if(p1[i] < 0 || p1[i] >= BASE)
			fatal(sys->sprint("bad array element %d: %d", i, p1[i]));
		if(0){
			p := p1[i];
			for(j := 0; j < LBASE; j++){
				f[p%10]++;
				p /= 10;
			}
		}
	}
	# prpi(p1);
	if(0){
		t := 0;
		for(i = 0; i < 10; i++){
			sys->print("%d	%d\n", i, f[i]);
			t += f[i];
		}
		sys->print("T	%d\n", t);
	}
}

terms(dp: int, f: int, v: int): (int, int)
{
	p := dp;
	t := 0;
	for(;;){
		t = 2 + int ((real p*log(real 10)+log(real v))/log(real f));
		if(!(t&1))
			t++;
		e := int (log(real (v*(t+1)/2))/log(real 10))+1;
		if(dp <= p-e)
			break;
		p += e;
	}
	# sys->fprint(stderr, "dp=%d p=%d f=%d v=%d terms=%d\n", dp, p, f, v, t);
	if(t < f*f)
		k := f*f;
	else
		k = t;
	m := BASE*k;
	if(m < 0 || m < BASE || m < k || m/BASE != k || m/k != BASE)
		return (-1, -1);
	return (t, p);
}

prpi(p: array of int)
{
	n := len p;
	sys->print("π ≅ ");
	m := BASE/10;
	sys->print("%d.%.*d", p[0]/m, LBASE-1, p[0]%m);
	for(i := 1; i < n; i++)
		sys->print("%.*d", LBASE, p[i]);
	sys->print("\n");
}

memcmp(b1: array of byte, b2: array of byte, n: int): (int, int, int)
{
	for(i := 0; i < n; i++)
		if(b1[i] != b2[i])
			return (i, int b1[i], int b2[i]);
	return (-1, 0, 0);
}

picmp(f1: string, f2: string)
{
	fd1 := sys->open(f1, Sys->OREAD);
	fd2 := sys->open(f2, Sys->OREAD);
	if(fd1 == nil || fd2 == nil)
		fatal(sys->sprint("cannot open %s or %s", f1, f2));
	b1 := array[Sys->ATOMICIO] of byte;
	b2 := array[Sys->ATOMICIO] of byte;
	t := 0;
	shouldexit := 0;
	for(;;){
		n1 := sys->read(fd1, b1, len b1);
		n2 := sys->read(fd2, b2, len b2);
		if(n1 <= 0 || n2 <= 0)
			return;
		if(shouldexit)
			fatal("bad picmp");
		if(n1 < n2)
			(d, v1, v2) := memcmp(b1, b2, n1);
		else
			(d, v1, v2) = memcmp(b1, b2, n2);
		if(d >= 0){
			if(v1 == '\n' || v2 == '\n')
				shouldexit = 1;
			else
				fatal(sys->sprint("%s %s differ at byte %d(%c %c)", f1, f2, t+d, v1, v2));
		}
		t += n1;
		if(n1 != n2)
			shouldexit = 1;
	}
}

roundup(n: int, m: int): (int, int)
{
	r := m*((n+m-1)/m);
	return (r, r/m);
}

pow(n: int, m: int): int
{
	p := 1;
	while(--m >= 0)
		p *= n;
	return p;
}

pi1(dp: int): array of int
{
	fs := array[2] of { 5, 239 };
	vs := array[2] of { 16, 4 };
	ss := array[2] of { 1, -1 };
	# sys->fprint(stderr, "π1\n");
	return pi(dp, fs, vs, ss);
}

pi2(dp: int): array of int
{
	fs := array[3] of { 18, 57, 239 };
	vs := array[3] of { 48, 32, 20 };
	ss := array[3] of { 1, 1, -1 };
	# sys->fprint(stderr, "π2\n");
	return pi(dp, fs, vs, ss);
}

pi3(dp: int): array of int
{
	fs := array[4] of { 57, 239, 682, 12943 };
	vs := array[4] of { 176, 28, 48, 96 };
	ss := array[4] of { 1, 1, -1, 1 };
	# sys->fprint(stderr, "π3\n");
	return pi(dp, fs, vs, ss);
}

pi(dp: int, fs: array of int, vs: array of int, ss: array of int): array of int
{
	k := len fs;
	n := cn := adp := 0;
	(dp, n) = roundup(dp, LBASE);
	cdp := dp;
	m := array[k] of int;
	for(i := 0; i < k; i++){
		(m[i], adp) = terms(dp+1, fs[i], vs[i]);
		if(m[i] < 0)
			return nil;
		if(adp > cdp)
			cdp = adp;
	}
	(cdp, cn) = roundup(cdp, LBASE);
	a := array[cn] of int;
	p := array[cn] of int;
	for(i = 0; i < cn; i++)
		p[i] = 0;
	for(i = 0; i < k; i++){
		series(m[i], cn, fs[i], (vs[i]*BASE)/10, ss[i], a, p);
		# sys->fprint(stderr, "term %d done\n", i+1);
	}
	return p[0: n];
}

series(m: int, n: int, f: int, v: int, s: int, a: array of int, p: array of int)
{
	i, j, k, q, r, r1, r2, n0: int;

	v *= f;
	f *= f;
	for(j = 0; j < n; j++)
		a[j] = 0;
	a[0] = v;

	if(s == 1)
		series1(m, n, f, v, a, p);
	else
		series2(m, n, f, v, a, p);
	return;

	# following code now split
	n0 = 0;	# reaches n when very close to m so no check needed
	for(i = 1; i <= m; i += 2){
		r1 = r2 = 0;
		for(j = n0; j < n; j++){
			v = a[j]+r1;
			q = v/f;
			r1 = (v-q*f)*BASE;
			a[j] = q;
			v = q+r2;
			q = v/i;
			r2 = (v-q*i)*BASE;
			for(k = j; q > 0; k--){
				r = p[k]+s*q;
				if(r >= BASE){
					p[k] = r-BASE;
					q = 1;
				}
				else if(r < 0){
					p[k] = r+BASE;
					q = 1;
				}
				else{
					p[k] = r;
					q = 0;
				}
			}
		}
		for(j = n0; j < n; j++){
			if(a[j] == 0)
				n0++;
			else
				break;
		}
		s = -s;
	}
}

series1(m: int, n: int, f: int, v: int, a: array of int, p: array of int)
{
	i, j, k, q, r, r1, r2, n0: int;

	n0 = 0;
	for(i = 1; i <= m; i += 2){
		r1 = r2 = 0;
		for(j = n0; j < n; j++){
			v = a[j]+r1;
			q = v/f;
			r1 = (v-q*f)*BASE;
			a[j] = q;
			v = q+r2;
			q = v/i;
			r2 = (v-q*i)*BASE;
			for(k = j; q > 0; k--){
				r = p[k]+q;
				if(r >= BASE){
					p[k] = r-BASE;
					q = 1;
				}
				else{
					p[k] = r;
					q = 0;
				}
			}
		}
		for(j = n0; j < n; j++){
			if(a[j] == 0)
				n0++;
			else
				break;
		}
		i += 2;
		r1 = r2 = 0;
		for(j = n0; j < n; j++){
			v = a[j]+r1;
			q = v/f;
			r1 = (v-q*f)*BASE;
			a[j] = q;
			v = q+r2;
			q = v/i;
			r2 = (v-q*i)*BASE;
			for(k = j; q > 0; k--){
				r = p[k]-q;
				if(r < 0){
					p[k] = r+BASE;
					q = 1;
				}
				else{
					p[k] = r;
					q = 0;
				}
			}
		}
		for(j = n0; j < n; j++){
			if(a[j] == 0)
				n0++;
			else
				break;
		}
	}
}

series2(m: int, n: int, f: int, v: int, a: array of int, p: array of int)
{
	i, j, k, q, r, r1, r2, n0: int;

	n0 = 0;
	for(i = 1; i <= m; i += 2){
		r1 = r2 = 0;
		for(j = n0; j < n; j++){
			v = a[j]+r1;
			q = v/f;
			r1 = (v-q*f)*BASE;
			a[j] = q;
			v = q+r2;
			q = v/i;
			r2 = (v-q*i)*BASE;
			for(k = j; q > 0; k--){
				r = p[k]-q;
				if(r < 0){
					p[k] = r+BASE;
					q = 1;
				}
				else{
					p[k] = r;
					q = 0;
				}
			}
		}
		for(j = n0; j < n; j++){
			if(a[j] == 0)
				n0++;
			else
				break;
		}
		i += 2;
		r1 = r2 = 0;
		for(j = n0; j < n; j++){
			v = a[j]+r1;
			q = v/f;
			r1 = (v-q*f)*BASE;
			a[j] = q;
			v = q+r2;
			q = v/i;
			r2 = (v-q*i)*BASE;
			for(k = j; q > 0; k--){
				r = p[k]+q;
				if(r >= BASE){
					p[k] = r-BASE;
					q = 1;
				}
				else{
					p[k] = r;
					q = 0;
				}
			}
		}
		for(j = n0; j < n; j++){
			if(a[j] == 0)
				n0++;
			else
				break;
		}
	}
}

sprint(x: Mp): string
{
	n := x[0];
	s := "";
	for(i := n; i > 0; --i)
		s += sys->sprint("%.*d\n", LMPBASE, x[i]);
	return s;
}

alloc(n: int): Mp
{
	x := array[n+1] of { * => 0 };
	x[0] = n;
	return x;
}

# normalized
nalloc(n: int): Mp
{
	x := alloc(n);
	x[0] = 1;
	return x;
}
	
num(n: int): Mp
{
	x := alloc(1);
	x[1] = n;
	return x;
}

copy(x: Mp): Mp
{
	k := len x - 1;	# TBS or x[0]
	y := alloc(k);
	for(i := 0; i <= k; i++)
		y[i] = x[i];
	return y;
}

asl(x: Mp, y: int, z: Mp): Mp
{
	m := x[0];
	q := y/LMPBASE;
	r := y-q*LMPBASE;
	n := q+m+1;
	z[0] = n-1;
	z[n] = 0;
	for(i := m; i > 0; --i)
		z[i+q] = x[i];
	for(i = 1; i <= q; i++)
		z[i] = 0;
	if(r != 0)
		z = muli(z, pow(10, r), z);
	return z;
}

asr(x: Mp, y: int, z: Mp): Mp
{
	m := x[0];
	q := y/LMPBASE;
	r := y-q*LMPBASE;
	if(m <= q){
		z[0] = 1;
		z[1] = 0;
		return z;
	}
	z[0] = m-q;
	for(i := q+1; i <= m; i++)
		z[i-q] = x[i];
	if(r != 0)
		z = divi(z, pow(10, r), z);
	return z;
}

add(x: Mp, y: Mp, z: Mp): Mp
{
	m := x[0];
	n := y[0];
	if(m < n)
		(x, y, m, n) = (y, x, n, m);
	z[0] = m+1;
	c := 0;
	for(i := 1; i <= n; i++){
		s := x[i]+y[i]+c;
		if(s >= MPBASE){
			z[i] = s-MPBASE;
			c = 1;
		}
		else{
			z[i] = s;
			c = 0;
		}
	}
	for( ; i <= m; i++){
		s := x[i]+c;
		if(s >= MPBASE){
			z[i] = s-MPBASE;
			c = 1;
		}
		else{
			z[i] = s;
			c = 0;
		}
	}
	if(c)
		z[i] = 1;
	else
		z[0] = m;
	return z;
}

sub(x: Mp, y: Mp, z: Mp): Mp
{
	m := x[0];
	n := y[0];
	# m >= n
	z[0] = m;
	c := 0;
	for(i := 1; i <= n; i++){
		s := x[i]-y[i]-c;
		if(s < 0){
			z[i] = s+MPBASE;
			c = 1;
		}
		else{
			z[i] = s;
			c = 0;
		}
	}
	for( ; i <= m; i++){
		s := x[i]-c;
		if(s < 0){
			z[i] = s+MPBASE;
			c = 1;
		}
		else{
			z[i] = s;
			c = 0;
		}
	}
	while(z[--i] == 0 && i > 1)
		;
	z[0] = i;
	return z;
}

# TBS simple approach first for testing
mul(x: Mp, y: Mp, z: Mp): Mp
{
	m := x[0];
	n := y[0];
    	for (j := 1; j <= n; j++)
		z[j] = 0;
    	for (i := 1; i <= m; i++){
		c := 0;
		for (j = 1; j <= n; j++)
			(c, z[i+j-1]) = mula(x[i], y[j], z[i+j-1]+c);
		z[i+j-1] = c;
	}
	i = m+n+1;
	while(z[--i] == 0 && i > 1)
		;
	z[0] = i;
	return z;
}

muli(x: Mp, y: int, z: Mp): Mp
{
	m := x[0];
	c := 0;
	for(i := 1; i <= m; i++){
		s := x[i]*y+c;		# TBS possible overflow
		# (c, z[i]) = mula(x[i], y, c);	TBS
		if(s >= MPBASE){
			c = s/MPBASE;
			z[i] = s-c*MPBASE;
		}
		else{
			z[i] = s;
			c = 0;
		}
	}
	if(c){
		z[i] = c;
		z[0] = i;
	}
	else
		z[0] = m;
	return z;
}

mula(x: int, y: int, z: int): (int, int)
{
	a := big x*big y + big z;
	return (int (a/big MPBASE), int (a%big MPBASE));
}

# TBS base power of 2 to make this faster
TBSmulii(x: int, y: int): (int, int)
{
	x1 := x/RMPBASE;
	x0 := x%RMPBASE;
	y1 := y/RMPBASE;
	y0 := y%RMPBASE;
	a := x0*y0;
	b := x0*y1+x1*y0;
	c := x1*y1;
	c += b/RMPBASE;
	b = b%RMPBASE+a/RMPBASE;
	if(b > RMPBASE){
		c++;
		b -= RMPBASE;
	}
	return (b*RMPBASE+a%RMPBASE, c);
}

divi(x: Mp, y: int, z: Mp): Mp
{
	a := MPBASE/y;
	b := MPBASE%y;
	m := x[0];
	c := 0;
	for(i := m; i >= 1; i--){
		s := x[i]+c*MPBASE;	# TBS possible overflow
		# (cc, c) = mula(c, MPBASE, x[i]);	# TBS check overflow
		# d := b*cc+c;
		# z[i] = a*cc+d/y;
		# c = d%y;
		z[i] = s/y;
		c = s%y;
	}
	i = m+1;
	while(z[--i] == 0 && i > 1)
		;
	z[0] = i;
	return z;
}

inv(x: Mp, y: Mp): Mp
{
	v: Mp;

	sub(muli(v, 2, nil), mul(x, mul(v, v, nil), nil), nil);
	return y;
}

sqrt(x: Mp, y: Mp): Mp
{
	return inv(invsqrt(x, copy(y)), y);	# TBS check
}

invsqrt(x: Mp, y: Mp): Mp
{
	v: Mp;

	sub(muli(v, 2, nil), mul(x, mul(v, v, nil), nil), nil);	# TBS wrong
	return y;
}

log10(x: int): int
{
	p := 1;
	for (i := 0; p <= x; p *= 10)
		i++;
	return i-1;
}

fatal(e: string)
{
	sys->print("%s\n", e);
	exit;
}
