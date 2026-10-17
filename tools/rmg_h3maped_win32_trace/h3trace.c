/* h3trace: attach-after-start breakpoint logger and New Map driver for a
 * seed-patched copy of h3maped.exe (SHA-256 4480fba1...). 32-bit Win32 tool;
 * written to be Wine-compatible but only exercised on Windows 10 so far.
 *
 * It starts h3maped normally (so the NT debug heap stays off), attaches once
 * the main window exists, logs every CRT rand() (0x4e727b, inside rand after
 * _getptd; state = ptd+0x14) and srand() (0x4e726e) call with the thread's
 * holdrand and caller stack, logs optional marker addresses, drives File > New
 * and the New Map dialog through window messages (SoD, no teams, water None unless --water),
 * saves through Save As and terminates the editor (no registry write-back).
 * Never point it at the HoMM3 install itself.
 *
 * h3trace <exe> <cwd> <log> <save.h3m> <hc> <co> <monster 0..3> [opts]
 *   hc: Human/Computer combo index (1 = "1"), co: Computer-only count
 *   monster: 0 random, 1 weak, 2 normal, 3 strong
 * Log lines: R rand, S srand, M marker (registers, 8 stack dwords, rng=),
 *   L memlog, V vecdump, D dump, A/H watch armed/hit, K rngskip, F stackfill.
 * opts:
 *   --mark ADDR                    log registers and stack at ADDR (repeatable)
 *   --dump ADDR:REG:OFF:DEREF:LEN  write LEN bytes at REG+OFF (DEREF 1: *(REG+OFF)) to a file per hit
 *   --memlog ADDR:REG:OFF:DEREF:LEN  same, as hex in the log
 *   --vecdump ADDR:REG:OFF:LEN     walk the pointer vector at REG+OFF/+4, log LEN bytes of each element
 *   --watch MARKER:VECOFF:IDX:OFF  at MARKER arm a hardware read/write watch on
 *                                  element IDX of the esi+VECOFF vector, +OFF (max 4)
 *   --rngskip ADDR:HIT:K           advance (K<0: rewind) the srand thread's holdrand at hit HIT (0 = every)
 *   --stackfill ADDR:SIZE:PAT      write SIZE bytes below esp at ADDR (PAT hex byte or r = pseudo-random)
 *   --poke ADDR:BYTE               write a byte into h3maped before driving the UI
 *   --norand                       markers only
 *   --nodebug                      drive and save without attaching
 *   --repeat N                     generate and save N times in one process (<save>_runK.h3m)
 *   --okmode 0..3                  OK by WM_COMMAND, posted click, BM_CLICK, posted Enter
 *   --clicks                       set the dialog with posted clicks/keys instead of control messages
 *   --manual                       do not drive the dialog; save after the generator returns (0x4ae082)
 *   --pid PID                      attach to a running editor instead of launching <exe>
 *   --set ADDR:REG:OFF:VALUE       write a dword at REG+OFF when ADDR is hit
 *   --detach ADDR:HIT              at that marker hit restore all breakpoints and detach (editor runs on)
 *   --size 36|72|108|144  --levels 1|2
 *   --water 0..3                   water radio: 0 random, 1 none (default), 2 normal, 3 islands
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RAND_BP 0x4e727bu
#define SRAND_BP 0x4e726eu

typedef struct { DWORD addr; BYTE orig; int kind; int armed; DWORD hits; } Bp;
typedef struct { DWORD addr; char reg[4]; DWORD off; int deref; DWORD len; } Dump;
typedef struct { DWORD tid; HANDLE h; DWORD rearm; } Th;

static Bp bps[64]; static int nbp;
static Dump dumps[32]; static int ndump;
static Dump mlogs[16]; static int nmlog;
static Dump vlogs[8]; static int nvlog;
typedef struct { DWORD marker; DWORD vecoff; int idx; DWORD fieldoff; DWORD addr; } Watch; static Watch watches[4]; static int nwatch;
static DWORD pokes[32][2]; static int npoke;
static Th ths[512]; static int nth;
static HANDLE hProc; static DWORD pid;
static FILE *logf;
static char logpath[MAX_PATH];
static DWORD seqno;
static HANDLE evReady;
static volatile LONG uiDone;
static int optNoDebug = 0, optRepeat = 1, optOkMode = 0, optManual = 0, optClicks = 0;
static DWORD optPid = 0;
typedef struct { DWORD addr; char reg[4]; DWORD off, value; } SetD; static SetD sets[8]; static int nset;
static DWORD detachAddr = 0, detachHit = 0; static int detachNow = 0; static HANDLE uiThreadHandle;
static DWORD doneAddr = 0x4ae082; static HANDLE evGenDone;
typedef struct { DWORD addr, size; int pat; } Fill; static Fill fills[8]; static int nfill;
typedef struct { DWORD addr, hit; int k; } Skip; static Skip skips[16]; static int nskip; static DWORD ptdMain;
static int optRand = 1, optSize = 36, optLevels = 1, optHc = 1, optCo = 1, optMon = 2, optWater = 1;
static char savePath[MAX_PATH];

static void logln(const char *fmt, ...) {
	va_list ap; va_start(ap, fmt); vfprintf(logf, fmt, ap); va_end(ap);
}

static HANDLE thread_handle(DWORD tid) {
	for (int i = 0; i < nth; ++i) if (ths[i].tid == tid) return ths[i].h;
	HANDLE h = OpenThread(THREAD_GET_CONTEXT | THREAD_SET_CONTEXT | THREAD_QUERY_INFORMATION | THREAD_SUSPEND_RESUME, FALSE, tid);
	if (nth < 512) { ths[nth].tid = tid; ths[nth].h = h; ths[nth].rearm = 0; ++nth; }
	return h;
}
static Th *thread_rec(DWORD tid) {
	thread_handle(tid);
	for (int i = 0; i < nth; ++i) if (ths[i].tid == tid) return &ths[i];
	return NULL;
}

static int rd(DWORD a, void *b, DWORD n) { SIZE_T got = 0; return ReadProcessMemory(hProc, (LPCVOID)(ULONG_PTR)a, b, n, &got) && got == n; }
static int wr(DWORD a, const void *b, DWORD n) {
	SIZE_T put = 0; DWORD old = 0;
	VirtualProtectEx(hProc, (LPVOID)(ULONG_PTR)a, n, PAGE_EXECUTE_READWRITE, &old);
	int ok = WriteProcessMemory(hProc, (LPVOID)(ULONG_PTR)a, b, n, &put) && put == n;
	VirtualProtectEx(hProc, (LPVOID)(ULONG_PTR)a, n, old, &old);
	FlushInstructionCache(hProc, (LPCVOID)(ULONG_PTR)a, n);
	return ok;
}

static void add_bp(DWORD addr, int kind) {
	for (int i = 0; i < nbp; ++i) if (bps[i].addr == addr) return;
	bps[nbp].addr = addr; bps[nbp].kind = kind; bps[nbp].armed = 0; bps[nbp].hits = 0; ++nbp;
}
static Bp *find_bp(DWORD addr) { for (int i = 0; i < nbp; ++i) if (bps[i].addr == addr) return &bps[i]; return NULL; }

static void arm_all(void) {
	static const BYTE cc = 0xCC;
	for (int i = 0; i < nbp; ++i) {
		if (bps[i].armed) continue;
		if (!rd(bps[i].addr, &bps[i].orig, 1)) { logln("E arm_read %08x %lu\n", bps[i].addr, GetLastError()); continue; }
		if (!wr(bps[i].addr, &cc, 1)) { logln("E arm_write %08x %lu\n", bps[i].addr, GetLastError()); continue; }
		bps[i].armed = 1;
	}
	for (int i = 0; i < npoke; ++i) {
		BYTE v = (BYTE)pokes[i][1], o = 0; rd(pokes[i][0], &o, 1);
		int ok = wr(pokes[i][0], &v, 1);
		logln("P %08x %02x->%02x %d\n", pokes[i][0], o, v, ok);
	}
}

static DWORD regval(const CONTEXT *c, const char *r) {
	if (!strcmp(r, "eax")) return c->Eax; if (!strcmp(r, "ebx")) return c->Ebx; if (!strcmp(r, "ecx")) return c->Ecx;
	if (!strcmp(r, "edx")) return c->Edx; if (!strcmp(r, "esi")) return c->Esi; if (!strcmp(r, "edi")) return c->Edi;
	if (!strcmp(r, "ebp")) return c->Ebp; if (!strcmp(r, "esp")) return c->Esp; return 0;
}

static void do_mlogs(DWORD addr, const CONTEXT *c) {
	for (int i = 0; i < nmlog; ++i) {
		if (mlogs[i].addr != addr) continue;
		DWORD base = regval(c, mlogs[i].reg) + mlogs[i].off;
		if (mlogs[i].deref) { DWORD p = 0; rd(base, &p, 4); base = p; }
		BYTE buf[256]; DWORD n = mlogs[i].len > 256 ? 256 : mlogs[i].len; memset(buf, 0, sizeof buf); rd(base, buf, n);
		logln("L %08x %d %08x", addr, i, base);
		for (DWORD k = 0; k + 4 <= n; k += 4) logln(" %08x", *(DWORD *)(buf + k));
		logln("\n");
	}
}
static void do_vlogs(DWORD addr, const CONTEXT *c) {
	for (int i = 0; i < nvlog; ++i) {
		if (vlogs[i].addr != addr) continue;
		DWORD be[2] = { 0, 0 }; rd(regval(c, vlogs[i].reg) + vlogs[i].off, be, 8);
		DWORD n = be[0] && be[1] > be[0] ? (be[1] - be[0]) / 4 : 0; if (n > 256) n = 256;
		for (DWORD k = 0; k < n; ++k) {
			DWORD p = 0; rd(be[0] + 4 * k, &p, 4);
			BYTE buf[256]; DWORD len = vlogs[i].len > 256 ? 256 : vlogs[i].len; memset(buf, 0, sizeof buf); rd(p, buf, len);
			logln("V %08x %d %u %08x", addr, i, k, p);
			for (DWORD j = 0; j + 4 <= len; j += 4) logln(" %08x", *(DWORD *)(buf + j));
			logln("\n");
		}
	}
}
static void do_dumps(DWORD addr, DWORD hit, const CONTEXT *c) {
	for (int i = 0; i < ndump; ++i) {
		if (dumps[i].addr != addr) continue;
		DWORD base = regval(c, dumps[i].reg) + dumps[i].off;
		if (dumps[i].deref) { DWORD p = 0; rd(base, &p, 4); base = p; }
		BYTE *buf = (BYTE *)malloc(dumps[i].len);
		int ok = buf && rd(base, buf, dumps[i].len);
		char name[MAX_PATH + 64];
		snprintf(name, sizeof name, "%s.dump_%08x_%u_%d.bin", logpath, addr, hit, i);
		if (ok) { FILE *f = fopen(name, "wb"); if (f) { fwrite(buf, 1, dumps[i].len, f); fclose(f); } }
		logln("D %u %08x hit=%u idx=%d base=%08x len=%u ok=%d\n", seqno++, addr, hit, i, base, dumps[i].len, ok);
		free(buf);
	}
}

static BOOL CALLBACK list_cb(HWND h, LPARAM l) {
	DWORD p = 0; DWORD tid = GetWindowThreadProcessId(h, &p);
	if (p != pid) return TRUE;
	char t[128] = { 0 }, c[64] = { 0 }; GetWindowTextA(h, t, sizeof t); GetClassNameA(h, c, sizeof c);
	logln("W tid=%lu hwnd=%p vis=%d class=%s title=%s\n", tid, (void *)h, IsWindowVisible(h) ? 1 : 0, c, t);
	return TRUE;
}
static DWORD handle_bp(DEBUG_EVENT *ev, Bp *b) {
	HANDLE ht = thread_handle(ev->dwThreadId);
	CONTEXT c; memset(&c, 0, sizeof c); c.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
	if (!GetThreadContext(ht, &c)) { logln("E getctx %lu\n", GetLastError()); return DBG_CONTINUE; }
	DWORD stk[12]; memset(stk, 0, sizeof stk); rd(c.Esp, stk, sizeof stk);
	b->hits++;
	if (b->kind == 1) { /* rand: mov ecx,[eax+0x14] */
		DWORD st = 0; rd(c.Eax + 0x14, &st, 4);
		logln("R %u %u %08x %08x %08x", seqno++, ev->dwThreadId, stk[0], st, c.Eax);
		for (int i = 1; i < 12; ++i) logln(" %08x", stk[i]);
		logln("\n");
		c.Ecx = st; c.Eip = b->addr + 3;
	} else if (b->kind == 2) { /* srand: mov ecx,[esp+4] */
		logln("S %u %u %08x %08x %08x\n", seqno++, ev->dwThreadId, stk[0], stk[1], c.Eax);
		c.Ecx = stk[1]; c.Eip = b->addr + 4;
		if (stk[0] == 0x49d9d1) ptdMain = c.Eax;
	} else { /* marker: log, then step over the original byte */
		logln("M %u %u %08x hit=%u eax=%08x ebx=%08x ecx=%08x edx=%08x esi=%08x edi=%08x ebp=%08x esp=%08x stk",
			seqno++, ev->dwThreadId, b->addr, b->hits, c.Eax, c.Ebx, c.Ecx, c.Edx, c.Esi, c.Edi, c.Ebp, c.Esp);
		for (int i = 0; i < 8; ++i) logln(" %08x", stk[i]);
		{ DWORD st = 0; if (ptdMain) rd(ptdMain + 0x14, &st, 4); logln(" rng=%08x", st); }
		logln("\n");
		do_dumps(b->addr, b->hits, &c);
		do_mlogs(b->addr, &c);
		do_vlogs(b->addr, &c);
		for (int i = 0; i < nset; ++i) {
			if (sets[i].addr != b->addr) continue;
			DWORD a = regval(&c, sets[i].reg) + sets[i].off, o = 0; rd(a, &o, 4);
			int ok = wr(a, &sets[i].value, 4);
			logln("T %u %08x set [%s+%x]=%08x (was %08x) ok=%d\n", seqno++, b->addr, sets[i].reg, sets[i].off, sets[i].value, o, ok);
		}
		{
			int any = 0;
			for (int i = 0; i < nwatch; ++i) {
				if (watches[i].marker != b->addr || watches[i].addr) continue;
				DWORD be[2] = { 0, 0 }; rd(c.Esi + watches[i].vecoff, be, 8);
				DWORD n = be[0] && be[1] > be[0] ? (be[1] - be[0]) / 4 : 0;
				if ((DWORD)watches[i].idx >= n) { logln("E watch idx %d >= %u\n", watches[i].idx, n); continue; }
				DWORD owner = 0; rd(be[0] + 4 * watches[i].idx, &owner, 4);
				watches[i].addr = owner + watches[i].fieldoff;
				DWORD v = 0; rd(watches[i].addr, &v, 4);
				logln("A %u watch%d owner[%d]=%08x+%x -> %08x value=%08x\n", seqno++, i, watches[i].idx, owner, watches[i].fieldoff, watches[i].addr, v);
				any = 1;
			}
			if (any) {
				CONTEXT d; memset(&d, 0, sizeof d); d.ContextFlags = CONTEXT_DEBUG_REGISTERS;
				HANDLE ht2 = thread_handle(ev->dwThreadId);
				GetThreadContext(ht2, &d);
				DWORD dr7 = 0;
				for (int i = 0; i < nwatch && i < 4; ++i) {
					if (!watches[i].addr) continue;
					DWORD *dr = i == 0 ? &d.Dr0 : i == 1 ? &d.Dr1 : i == 2 ? &d.Dr2 : &d.Dr3;
					*dr = watches[i].addr & ~3u;
					dr7 |= (1u << (i * 2)) | (3u << (16 + i * 4)) | (3u << (18 + i * 4));
				}
				d.Dr7 = dr7; d.Dr6 = 0;
				SetThreadContext(ht2, &d);
				/* also make sure the marker context write below keeps the debug registers */
				c.ContextFlags |= CONTEXT_DEBUG_REGISTERS; c.Dr0 = d.Dr0; c.Dr1 = d.Dr1; c.Dr2 = d.Dr2; c.Dr3 = d.Dr3; c.Dr7 = d.Dr7; c.Dr6 = 0;
			}
		}
		if (b->addr == doneAddr && evGenDone) SetEvent(evGenDone);
		if (b->addr == 0x4ac7ef && b->hits == 1) { logln("W marker tid=%lu\n", ev->dwThreadId); EnumWindows(list_cb, 0); }
		for (int i = 0; i < nskip; ++i) {
			if (skips[i].addr != b->addr || (skips[i].hit && skips[i].hit != b->hits) || !ptdMain) continue;
			DWORD st = 0; rd(ptdMain + 0x14, &st, 4); DWORD st0 = st;
			for (int k = 0; k < skips[i].k; ++k) st = st * 0x343fdu + 0x269ec3u;
			for (int k = 0; k > skips[i].k; --k) st = (st - 0x269ec3u) * 0xb9b33155u;
			int ok = wr(ptdMain + 0x14, &st, 4);
			logln("K %u %08x hit=%u k=%d %08x->%08x ok=%d\n", seqno++, b->addr, b->hits, skips[i].k, st0, st, ok);
		}
		for (int i = 0; i < nfill; ++i) {
			if (fills[i].addr != b->addr) continue;
			DWORD n = fills[i].size; BYTE *buf = (BYTE *)malloc(n); DWORD x = 0x12345678u;
			for (DWORD k = 0; k < n; ++k) { if (fills[i].pat < 0) { x = x * 1103515245u + 12345u; buf[k] = (BYTE)(x >> 16); } else buf[k] = (BYTE)fills[i].pat; }
			int ok = wr(c.Esp - n, buf, n);
			logln("F %u %08x below_esp=%08x size=%u pat=%d ok=%d\n", seqno++, b->addr, c.Esp, n, fills[i].pat, ok);
			free(buf);
		}
		wr(b->addr, &b->orig, 1);
		c.Eip = b->addr;
		if (detachAddr && b->addr == detachAddr && b->hits == detachHit) {
			/* restore every breakpoint byte and let the thread run on without a single-step */
			for (int i = 0; i < nbp; ++i) if (bps[i].armed) { wr(bps[i].addr, &bps[i].orig, 1); bps[i].armed = 0; }
			detachNow = 1;
			logln("I detach at %08x hit=%u\n", b->addr, b->hits);
			if (evGenDone) SetEvent(evGenDone);
		} else {
			c.EFlags |= 0x100;
			Th *t = thread_rec(ev->dwThreadId); if (t) t->rearm = b->addr;
		}
	}
	if (!SetThreadContext(ht, &c)) logln("E setctx %lu\n", GetLastError());
	return DBG_CONTINUE;
}

/* ---------------- UI driving ---------------- */
typedef struct { DWORD pid; const char *title; int contains; HWND found; } FindCtx;
static BOOL CALLBACK find_cb(HWND h, LPARAM l) {
	FindCtx *f = (FindCtx *)l; DWORD p = 0; GetWindowThreadProcessId(h, &p);
	if (p != f->pid || !IsWindowVisible(h)) return TRUE;
	char t[256]; GetWindowTextA(h, t, sizeof t);
	if ((f->contains && strstr(t, f->title)) || (!f->contains && !strcmp(t, f->title))) { f->found = h; return FALSE; }
	return TRUE;
}
static HWND find_top(const char *title, int contains) { FindCtx f = { pid, title, contains, NULL }; EnumWindows(find_cb, (LPARAM)&f); return f.found; }
static HWND wait_top(const char *title, int contains, int ms) {
	for (int t = 0; t < ms; t += 100) { HWND h = find_top(title, contains); if (h) return h; Sleep(100); }
	return NULL;
}
static LRESULT smt(HWND h, UINT m, WPARAM w, LPARAM l) { DWORD_PTR r = 0; SendMessageTimeoutA(h, m, w, l, SMTO_NORMAL, 60000, &r); return (LRESULT)r; }
static void set_check(HWND dlg, int id, int on) {
	HWND c = GetDlgItem(dlg, id);
	int cur = (int)smt(c, BM_GETCHECK, 0, 0);
	if (!!cur == !!on) return;
	smt(c, BM_SETCHECK, on ? BST_CHECKED : BST_UNCHECKED, 0);
	smt(dlg, WM_COMMAND, MAKEWPARAM(id, BN_CLICKED), (LPARAM)c);
}
static void set_radio(HWND dlg, const int *ids, int n, int target) {
	for (int i = 0; i < n; ++i) smt(GetDlgItem(dlg, ids[i]), BM_SETCHECK, ids[i] == target ? BST_CHECKED : BST_UNCHECKED, 0);
	smt(dlg, WM_COMMAND, MAKEWPARAM(target, BN_CLICKED), (LPARAM)GetDlgItem(dlg, target));
}
static void set_combo(HWND dlg, int id, int idx) {
	HWND c = GetDlgItem(dlg, id);
	smt(c, CB_SETCURSEL, idx, 0);
	smt(dlg, WM_COMMAND, MAKEWPARAM(id, CBN_SELCHANGE), (LPARAM)c);
}
static void post_click(HWND h) {
	PostMessageA(h, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(4, 4)); Sleep(60);
	PostMessageA(h, WM_LBUTTONUP, 0, MAKELPARAM(4, 4)); Sleep(250);
}
static void post_key(HWND h, int vk) {
	PostMessageA(h, WM_KEYDOWN, vk, 1); Sleep(40);
	PostMessageA(h, WM_KEYUP, vk, 0xC0000001); Sleep(150);
}
static void combo_pick(HWND dlg, int id, int downs) {
	HWND c = GetDlgItem(dlg, id);
	post_click(c); Sleep(300);
	for (int i = 0; i < downs; ++i) post_key(c, VK_DOWN);
	post_key(c, VK_RETURN); Sleep(300);
}
static int responsive(HWND h) { DWORD_PTR r; return SendMessageTimeoutA(h, WM_NULL, 0, 0, SMTO_ABORTIFHUNG, 500, &r) != 0; }

static DWORD WINAPI ui_thread(LPVOID unused) {
	(void)unused;
	WaitForSingleObject(evReady, INFINITE);
	Sleep(500);
	HWND main = find_top("Map Editor", 1);
	fprintf(stderr, "ui: main=%p\n", (void *)main);
	char baseSave[MAX_PATH]; strncpy(baseSave, savePath, MAX_PATH - 1); baseSave[MAX_PATH - 1] = 0;
	for (int rep = 0; rep < optRepeat; ++rep) {
	if (optRepeat > 1) { char *dot = strrchr(baseSave, '.'); snprintf(savePath, MAX_PATH, "%.*s_run%d%s", (int)(dot - baseSave), baseSave, rep + 1, dot); DeleteFileA(savePath); }
	fprintf(stderr, "ui: generation %d -> %s\n", rep + 1, savePath);
	if (optManual) {
		fprintf(stderr, "ui: manual mode, waiting for generation end marker%s", "\n");
		WaitForSingleObject(evGenDone, INFINITE);
		for (int t = 0; t < 1200000; t += 500) { if (!find_top("Generating", 1) && responsive(main)) break; Sleep(500); }
		Sleep(1500);
		goto save;
	}
	if (optClicks) { HWND sb = GetDlgItem(main, 59393); post_click(sb); Sleep(500); }
	PostMessageA(main, WM_COMMAND, 57600, 0);
	HWND dlg = wait_top("New Map", 0, 20000);
	fprintf(stderr, "ui: new map dialog=%p\n", (void *)dlg);
	if (!dlg) { InterlockedExchange(&uiDone, 2); return 0; }
	if (optClicks) {
		HWND db = GetDlgItem(dlg, 1185);
		fprintf(stderr, "ui: clicks mode, two-level=%d random=%d hc=%d co=%d\n", (int)smt(db, BM_GETCHECK, 0, 0), (int)smt(GetDlgItem(dlg, 1822), BM_GETCHECK, 0, 0),
			(int)smt(GetDlgItem(dlg, 1852), CB_GETCURSEL, 0, 0), (int)smt(GetDlgItem(dlg, 1853), CB_GETCURSEL, 0, 0));
		post_click(GetDlgItem(dlg, optSize == 36 ? 1020 : 1021));
		if ((int)smt(db, BM_GETCHECK, 0, 0) != (optLevels == 2)) post_click(db);
		post_click(GetDlgItem(dlg, 1822)); Sleep(800);
		combo_pick(dlg, 1852, optHc);
		combo_pick(dlg, 1853, optCo + 1);
		{ static const int wids[] = { 1863, 1856, 1859, 1858 }; post_click(GetDlgItem(dlg, wids[optWater])); }
		post_click(GetDlgItem(dlg, optMon == 1 ? 1860 : optMon == 2 ? 1861 : optMon == 3 ? 1862 : 1864));
		Sleep(400);
		fprintf(stderr, "ui: after clicks two-level=%d random=%d hc=%d co=%d t=%d t=%d water=%d mon=%d\n", (int)smt(db, BM_GETCHECK, 0, 0), (int)smt(GetDlgItem(dlg, 1822), BM_GETCHECK, 0, 0),
			(int)smt(GetDlgItem(dlg, 1852), CB_GETCURSEL, 0, 0), (int)smt(GetDlgItem(dlg, 1853), CB_GETCURSEL, 0, 0),
			(int)smt(GetDlgItem(dlg, 1854), CB_GETCURSEL, 0, 0), (int)smt(GetDlgItem(dlg, 1855), CB_GETCURSEL, 0, 0),
			(int)smt(GetDlgItem(dlg, 1856), BM_GETCHECK, 0, 0), (int)smt(GetDlgItem(dlg, 1861), BM_GETCHECK, 0, 0));
		post_click(GetDlgItem(dlg, IDOK));
		goto wait_gen;
	}
	static const int ver[] = { 1848, 1849, 1922 }, sz[] = { 1020, 1021, 1022, 1023 };
	static const int water[] = { 1863, 1856, 1859, 1858 }, mon[] = { 1864, 1860, 1861, 1862 };
	set_radio(dlg, ver, 3, 1922);
	set_radio(dlg, sz, 4, optSize == 36 ? 1020 : optSize == 72 ? 1021 : optSize == 108 ? 1022 : 1023);
	set_check(dlg, 1185, optLevels == 2);
	set_check(dlg, 1822, 1);
	Sleep(200);
	set_combo(dlg, 1852, optHc);
	set_combo(dlg, 1853, optCo + 1);
	set_combo(dlg, 1854, 1);
	set_combo(dlg, 1855, 1);
	set_radio(dlg, water, 4, water[optWater]);
	{ char wt[64] = ""; GetWindowTextA(GetDlgItem(dlg, water[optWater]), wt, sizeof wt); fprintf(stderr, "ui: water %d \"%s\"\n", optWater, wt); }
	set_radio(dlg, mon, 4, mon[optMon]);
	Sleep(300);
	fprintf(stderr, "ui: combos hc=%d co=%d t=%d t=%d\n", (int)smt(GetDlgItem(dlg, 1852), CB_GETCURSEL, 0, 0),
		(int)smt(GetDlgItem(dlg, 1853), CB_GETCURSEL, 0, 0), (int)smt(GetDlgItem(dlg, 1854), CB_GETCURSEL, 0, 0),
		(int)smt(GetDlgItem(dlg, 1855), CB_GETCURSEL, 0, 0));
	{
		HWND ok = GetDlgItem(dlg, IDOK);
		fprintf(stderr, "ui: ok mode %d\n", optOkMode);
		if (optOkMode == 1) { PostMessageA(ok, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(5, 5)); PostMessageA(ok, WM_LBUTTONUP, 0, MAKELPARAM(5, 5)); }
		else if (optOkMode == 2) { DWORD_PTR r; SendMessageTimeoutA(ok, BM_CLICK, 0, 0, SMTO_NORMAL, 600000, &r); }
		else if (optOkMode == 3) { PostMessageA(dlg, WM_KEYDOWN, VK_RETURN, 0); PostMessageA(dlg, WM_KEYUP, VK_RETURN, 0xC0000001); }
		else PostMessageA(dlg, WM_COMMAND, MAKEWPARAM(IDOK, BN_CLICKED), (LPARAM)ok);
	}
	wait_gen:
	/* wait for the dialog to go and the main window to answer again */
	for (int t = 0; t < 600000; t += 200) { if (!IsWindow(dlg)) break; Sleep(200); }
	Sleep(1000);
	for (int t = 0; t < 1200000; t += 500) {
		if (!find_top("Generating", 1) && responsive(main)) break;
		Sleep(500);
	}
	Sleep(1500);
	save:
	fprintf(stderr, "ui: generation finished, saving\n");
	PostMessageA(main, WM_COMMAND, 57604, 0);
	HWND sd = wait_top("Save As", 0, 20000);
	fprintf(stderr, "ui: save dialog=%p\n", (void *)sd);
	if (!sd) { InterlockedExchange(&uiDone, 3); return 0; }
	Sleep(500);
	HWND edit = GetDlgItem(sd, 1148); if (!edit) edit = GetDlgItem(sd, 1152);
	fprintf(stderr, "ui: filename control=%p\n", (void *)edit);
	smt(edit, WM_SETTEXT, 0, (LPARAM)savePath);
	Sleep(200);
	PostMessageA(sd, WM_COMMAND, MAKEWPARAM(IDOK, BN_CLICKED), (LPARAM)GetDlgItem(sd, IDOK));
	for (int t = 0; t < 30000; t += 200) {
		WIN32_FILE_ATTRIBUTE_DATA a;
		if (GetFileAttributesExA(savePath, GetFileExInfoStandard, &a) && a.nFileSizeLow > 0 && !IsWindow(sd)) break;
		Sleep(200);
	}
	Sleep(1500);
	fprintf(stderr, "ui: saved %s\n", savePath);
	}
	fprintf(stderr, "ui: terminating\n");
	InterlockedExchange(&uiDone, 1);
	TerminateProcess(hProc, 0);
	return 0;
}

static DWORD parse_hex(const char *s) { return (DWORD)strtoul(s, NULL, 0); }

int main(int argc, char **argv) {
	if (argc < 8) { fprintf(stderr, "usage: h3trace exe cwd log save hc co monster [opts]\n"); return 2; }
	const char *exe = argv[1], *cwd = argv[2];
	strncpy(logpath, argv[3], MAX_PATH - 1);
	GetFullPathNameA(argv[4], MAX_PATH, savePath, NULL);
	optHc = atoi(argv[5]); optCo = atoi(argv[6]); optMon = atoi(argv[7]);
	for (int i = 8; i < argc; ++i) {
		if (!strcmp(argv[i], "--mark") && i + 1 < argc) add_bp(parse_hex(argv[++i]), 3);
		else if (!strcmp(argv[i], "--norand")) optRand = 0;
		else if (!strcmp(argv[i], "--nodebug")) optNoDebug = 1;
		else if (!strcmp(argv[i], "--manual")) optManual = 1;
		else if (!strcmp(argv[i], "--set") && i + 1 < argc && nset < 8) {
			char buf[96]; strncpy(buf, argv[++i], 95); buf[95] = 0;
			char *a = strtok(buf, ":"), *r = strtok(NULL, ":"), *o = strtok(NULL, ":"), *v = strtok(NULL, ":");
			if (a && r && o && v) { sets[nset].addr = parse_hex(a); strncpy(sets[nset].reg, r, 3); sets[nset].reg[3] = 0; sets[nset].off = parse_hex(o); sets[nset].value = parse_hex(v); add_bp(sets[nset].addr, 3); ++nset; }
		}
		else if (!strcmp(argv[i], "--detach") && i + 1 < argc) {
			char buf[64]; strncpy(buf, argv[++i], 63); buf[63] = 0;
			char *a = strtok(buf, ":"), *h = strtok(NULL, ":");
			if (a && h) { detachAddr = parse_hex(a); detachHit = parse_hex(h); add_bp(detachAddr, 3); }
		}
		else if (!strcmp(argv[i], "--pid") && i + 1 < argc) optPid = (DWORD)strtoul(argv[++i], NULL, 0);
		else if (!strcmp(argv[i], "--clicks")) optClicks = 1;
		else if (!strcmp(argv[i], "--watch") && i + 1 < argc && nwatch < 4) {
			char buf[128]; strncpy(buf, argv[++i], 127); buf[127] = 0;
			char *a = strtok(buf, ":"), *v = strtok(NULL, ":"), *ix = strtok(NULL, ":"), *f = strtok(NULL, ":");
			if (a && v && ix && f) { watches[nwatch].marker = parse_hex(a); watches[nwatch].vecoff = parse_hex(v); watches[nwatch].idx = atoi(ix); watches[nwatch].fieldoff = parse_hex(f); watches[nwatch].addr = 0; add_bp(watches[nwatch].marker, 3); ++nwatch; }
		}
		else if (!strcmp(argv[i], "--vecdump") && i + 1 < argc && nvlog < 8) {
			char buf[256]; strncpy(buf, argv[++i], 255); buf[255] = 0;
			char *a = strtok(buf, ":"), *r = strtok(NULL, ":"), *o = strtok(NULL, ":"), *l = strtok(NULL, ":");
			if (a && r && o && l) { vlogs[nvlog].addr = parse_hex(a); strncpy(vlogs[nvlog].reg, r, 3); vlogs[nvlog].reg[3] = 0; vlogs[nvlog].off = parse_hex(o); vlogs[nvlog].len = parse_hex(l); add_bp(vlogs[nvlog].addr, 3); ++nvlog; }
		}
		else if (!strcmp(argv[i], "--memlog") && i + 1 < argc && nmlog < 16) {
			char buf[256]; strncpy(buf, argv[++i], 255); buf[255] = 0;
			char *p[5]; int k = 0; p[k++] = strtok(buf, ":"); while (k < 5 && (p[k] = strtok(NULL, ":"))) ++k;
			if (k == 5) {
				mlogs[nmlog].addr = parse_hex(p[0]); strncpy(mlogs[nmlog].reg, p[1], 3); mlogs[nmlog].reg[3] = 0;
				mlogs[nmlog].off = parse_hex(p[2]); mlogs[nmlog].deref = atoi(p[3]); mlogs[nmlog].len = parse_hex(p[4]);
				add_bp(mlogs[nmlog].addr, 3); ++nmlog;
			}
		}
		else if (!strcmp(argv[i], "--rngskip") && i + 1 < argc && nskip < 16) {
			char buf[128]; strncpy(buf, argv[++i], 127); buf[127] = 0;
			char *a = strtok(buf, ":"), *h = strtok(NULL, ":"), *k = strtok(NULL, ":");
			if (a && h && k) { skips[nskip].addr = parse_hex(a); skips[nskip].hit = parse_hex(h); skips[nskip].k = atoi(k); add_bp(skips[nskip].addr, 3); ++nskip; }
		}
		else if (!strcmp(argv[i], "--stackfill") && i + 1 < argc && nfill < 8) {
			char buf[128]; strncpy(buf, argv[++i], 127); buf[127] = 0;
			char *a = strtok(buf, ":"), *z = strtok(NULL, ":"), *p = strtok(NULL, ":");
			if (a && z && p) { fills[nfill].addr = parse_hex(a); fills[nfill].size = parse_hex(z); fills[nfill].pat = (*p == 'r') ? -1 : (int)parse_hex(p); add_bp(fills[nfill].addr, 3); ++nfill; }
		}
		else if (!strcmp(argv[i], "--okmode") && i + 1 < argc) optOkMode = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--repeat") && i + 1 < argc) optRepeat = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--size") && i + 1 < argc) optSize = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--levels") && i + 1 < argc) optLevels = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--water") && i + 1 < argc) { optWater = atoi(argv[++i]); if (optWater < 0 || optWater > 3) optWater = 1; }
		else if (!strcmp(argv[i], "--poke") && i + 1 < argc) {
			char *s = argv[++i]; char *colon = strchr(s, ':');
			if (colon && npoke < 32) { *colon = 0; pokes[npoke][0] = parse_hex(s); pokes[npoke][1] = parse_hex(colon + 1); ++npoke; }
		} else if (!strcmp(argv[i], "--dump") && i + 1 < argc && ndump < 32) {
			char buf[256]; strncpy(buf, argv[++i], 255); buf[255] = 0;
			char *p[5]; int k = 0; p[k++] = strtok(buf, ":"); while (k < 5 && (p[k] = strtok(NULL, ":"))) ++k;
			if (k == 5) {
				dumps[ndump].addr = parse_hex(p[0]); strncpy(dumps[ndump].reg, p[1], 3); dumps[ndump].reg[3] = 0;
				dumps[ndump].off = parse_hex(p[2]); dumps[ndump].deref = atoi(p[3]); dumps[ndump].len = parse_hex(p[4]);
				add_bp(dumps[ndump].addr, 3); ++ndump;
			}
		}
	}
	if (optRand) { add_bp(RAND_BP, 1); add_bp(SRAND_BP, 2); }
	logf = fopen(logpath, "w");
	if (!logf) { fprintf(stderr, "cannot open log\n"); return 2; }
	setvbuf(logf, NULL, _IOFBF, 1 << 20);
	DeleteFileA(savePath);

	STARTUPINFOA si; PROCESS_INFORMATION pi; memset(&si, 0, sizeof si); si.cb = sizeof si; memset(&pi, 0, sizeof pi);
	if (optPid) {
		/* attach to an editor someone else started (e.g. from the desktop) */
		pid = optPid;
		fprintf(stderr, "attaching to pid=%lu\n", pid);
	} else {
		char cmd[MAX_PATH + 8]; snprintf(cmd, sizeof cmd, "\"%s\"", exe);
		if (!CreateProcessA(exe, cmd, NULL, NULL, FALSE, 0, NULL, cwd, &si, &pi)) { fprintf(stderr, "CreateProcess %lu\n", GetLastError()); return 3; }
		pid = pi.dwProcessId;
		fprintf(stderr, "launched pid=%lu\n", pid);
	}
	for (int t = 0; t < 60000; t += 100) { if (find_top("Map Editor", 1)) break; Sleep(100); }
	Sleep(2000);
	if (optNoDebug) {
		hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
		for (int i = 0; i < npoke; ++i) { BYTE v = (BYTE)pokes[i][1]; logln("P %08x %02x %d\n", pokes[i][0], v, wr(pokes[i][0], &v, 1)); }
		evReady = CreateEventA(NULL, TRUE, TRUE, NULL);
		HANDLE ut = CreateThread(NULL, 0, ui_thread, NULL, 0, NULL);
		WaitForSingleObject(ut, INFINITE);
		WaitForSingleObject(pi.hProcess, 10000);
		fclose(logf);
		fprintf(stderr, "done (nodebug) ui=%ld\n", uiDone);
		return uiDone == 1 ? 0 : 5;
	}
	if (!DebugActiveProcess(pid)) { fprintf(stderr, "DebugActiveProcess %lu\n", GetLastError()); return 4; }
	DebugSetProcessKillOnExit(TRUE);
	evReady = CreateEventA(NULL, TRUE, FALSE, NULL);
	evGenDone = CreateEventA(NULL, TRUE, FALSE, NULL);
	add_bp(doneAddr, 3);
	uiThreadHandle = CreateThread(NULL, 0, ui_thread, NULL, 0, NULL);
	logln("I pid=%lu\n", pid);

	DEBUG_EVENT ev;
	int running = 1;
	while (running && WaitForDebugEvent(&ev, INFINITE)) {
		DWORD cont = DBG_CONTINUE;
		switch (ev.dwDebugEventCode) {
		case CREATE_PROCESS_DEBUG_EVENT:
			hProc = ev.u.CreateProcessInfo.hProcess;
			if (ev.u.CreateProcessInfo.hFile) CloseHandle(ev.u.CreateProcessInfo.hFile);
			arm_all();
			logln("I armed=%d\n", nbp);
			SetEvent(evReady);
			break;
		case LOAD_DLL_DEBUG_EVENT:
			if (ev.u.LoadDll.hFile) CloseHandle(ev.u.LoadDll.hFile);
			break;
		case EXIT_PROCESS_DEBUG_EVENT:
			running = 0;
			break;
		case EXCEPTION_DEBUG_EVENT: {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			DWORD addr = (DWORD)(ULONG_PTR)ev.u.Exception.ExceptionRecord.ExceptionAddress;
			if (code == EXCEPTION_BREAKPOINT) {
				Bp *b = find_bp(addr);
				if (b && b->armed) cont = handle_bp(&ev, b);
				else cont = DBG_CONTINUE; /* attach breakpoint */
			} else if (code == EXCEPTION_SINGLE_STEP) {
				Th *t = thread_rec(ev.dwThreadId);
				int handled = 0;
				if (nwatch) {
					CONTEXT d; memset(&d, 0, sizeof d); d.ContextFlags = CONTEXT_DEBUG_REGISTERS | CONTEXT_CONTROL | CONTEXT_INTEGER;
					HANDLE ht2 = thread_handle(ev.dwThreadId);
					if (GetThreadContext(ht2, &d) && (d.Dr6 & 0xF)) {
						for (int i = 0; i < 4; ++i) if (d.Dr6 & (1u << i)) {
							DWORD v = 0; rd(watches[i].addr, &v, 4);
							DWORD stk[4] = { 0 }; rd(d.Esp, stk, sizeof stk);
							logln("H %u %lu watch%d eip=%08x addr=%08x value=%08x esp=%08x stk %08x %08x %08x %08x\n", seqno++, ev.dwThreadId, i, d.Eip, watches[i].addr, v, d.Esp, stk[0], stk[1], stk[2], stk[3]);
						}
						d.Dr6 = 0; d.ContextFlags = CONTEXT_DEBUG_REGISTERS; SetThreadContext(ht2, &d);
						handled = 1;
					}
				}
				if (t && t->rearm) { static const BYTE cc = 0xCC; wr(t->rearm, &cc, 1); t->rearm = 0; handled = 1; }
				cont = handled ? DBG_CONTINUE : DBG_EXCEPTION_NOT_HANDLED;
			} else {
				if (ev.u.Exception.dwFirstChance) logln("X %u %u %08x %08x\n", seqno++, ev.dwThreadId, code, addr);
				cont = DBG_EXCEPTION_NOT_HANDLED;
			}
			break;
		}
		default: break;
		}
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
		if (detachNow) {
			DebugActiveProcessStop(pid);
			hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
			running = 0;
		}
	}
	if (detachNow) WaitForSingleObject(uiThreadHandle, INFINITE);
	logln("I end ui=%ld events=%u\n", uiDone, seqno);
	for (int i = 0; i < nbp; ++i) logln("B %08x kind=%d hits=%u\n", bps[i].addr, bps[i].kind, bps[i].hits);
	fclose(logf);
	fprintf(stderr, "done ui=%ld events=%u\n", uiDone, seqno);
	return uiDone == 1 ? 0 : 5;
}
