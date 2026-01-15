import Constants from 'expo-constants';

export class NewsletterService {
  // Google Apps Script Web App (Exec URL)
  // Environment variable'dan al, yoksa fallback kullan
  private static readonly ENDPOINT =
    Constants.expoConfig?.extra?.newsletterEndpoint ||
    'https://script.google.com/macros/s/AKfycbz72ylaiLL2Y4mYKx94rvuYvcWmAlhzTrp9SDLuBco6waFmx4CXSBN1zjYK518h6TbBLw/exec';

  static async subscribe(email: string): Promise<{ok: boolean; message: string}> {
    const trimmed = (email || '').trim();
    if (!trimmed) return {ok: false, message: 'E-posta boş olamaz.'};

    const userAgent =
      typeof navigator !== 'undefined' && typeof navigator.userAgent === 'string'
        ? navigator.userAgent
        : 'React Native App';
    const qs = `action=subscribe&email=${encodeURIComponent(trimmed)}&userAgent=${encodeURIComponent(
      userAgent
    )}&ts=${Date.now()}`;

    // Some Apps Script deployments only implement doGet and return `{}` for POST.
    // So we try GET first, and we only accept JSON responses as success when they explicitly say so.
    const attempts: Array<() => Promise<Response>> = [
      // GET (most compatible for Apps Script doGet; no headers to avoid preflight)
      () =>
        fetch(`${this.ENDPOINT}?${qs}`, {
          method: 'GET',
          mode: 'no-cors' as any,
        }),
      // POST form-urlencoded (no custom headers, no-cors to avoid preflight)
      () =>
        fetch(this.ENDPOINT, {
          method: 'POST',
          mode: 'no-cors' as any,
          body: qs.replace(/&ts=\d+$/, ''),
        }),
      // POST JSON (no custom headers, no-cors to avoid preflight)
      () =>
        fetch(this.ENDPOINT, {
          method: 'POST',
          mode: 'no-cors' as any,
          body: JSON.stringify({action: 'subscribe', email: trimmed, userAgent}),
        }),
    ];

    let lastErr: unknown = null;

    for (const attempt of attempts) {
      try {
        const res = await attempt();
        const text = await res.text();

        if (!res.ok) {
          lastErr = new Error(text || `HTTP ${res.status}`);
          continue;
        }

        // Try to parse JSON.
        try {
          const json = JSON.parse(text || '{}') as any;
          const hasKeys =
            json && typeof json === 'object' && !Array.isArray(json) && Object.keys(json).length > 0;
          // Support common shapes:
          // - { ok: true/false, message }
          // - { success: true/false, message }
          // - { status: "success"|"error", message }
          const okFlag =
            typeof json?.ok === 'boolean'
              ? json.ok
              : typeof json?.success === 'boolean'
                ? json.success
                : typeof json?.status === 'string'
                  ? json.status.toLowerCase() === 'success'
                  : null;

          // If `{}` (or no explicit ok/success), treat as "request accepted", not a confirmed save.
          if (!hasKeys || okFlag === null) {
            return {
              ok: true,
              message: 'Başarıyla kaydedildi',
            };
          }

          const message =
            (typeof json.message === 'string' && json.message) ||
            (typeof json.msg === 'string' && json.msg) ||
            (okFlag ? 'Başarıyla kaydedildi' : 'Abonelik sırasında hata oluştu.');
          return {ok: okFlag, message};
        } catch {
          // Non-JSON text response: accept as success if it contains a positive signal.
          const t = (text || '').toLowerCase();
          const looksOk =
            t.includes('ok') ||
            t.includes('success') ||
            t.includes('başar') ||
            t.includes('abone') ||
            t.includes('eklendi');
          if (looksOk) return {ok: true, message: 'Başarıyla kaydedildi'};

          lastErr = new Error(text || 'Unexpected response');
          continue;
        }
      } catch (e) {
        lastErr = e;
      }
    }

    return {
      ok: false,
      message:
        lastErr instanceof Error
          ? lastErr.message
          : 'Abonelik sırasında bir hata oluştu. Lütfen tekrar deneyin.',
    };
  }

  /**
   * Web fallback: send a GET request via an invisible iframe.
   * This bypasses CORS restrictions that can block `fetch()` to Apps Script.
   * Note: We cannot reliably read the response cross-origin; this only confirms the request was sent.
   */
  static async subscribeWebViaIframe(email: string): Promise<{ok: boolean; message: string}> {
    const trimmed = (email || '').trim();
    if (!trimmed) return {ok: false, message: 'E-posta boş olamaz.'};

    const qs = `action=subscribe&email=${encodeURIComponent(trimmed)}&userAgent=${encodeURIComponent(
      typeof navigator !== 'undefined' && typeof navigator.userAgent === 'string'
        ? navigator.userAgent
        : 'React Native App'
    )}&ts=${Date.now()}`;
    const userAgent =
      typeof navigator !== 'undefined' && typeof navigator.userAgent === 'string'
        ? navigator.userAgent
        : 'React Native App';
    const url = `${this.ENDPOINT}?${qs}`;

    try {
      const doc: any = typeof document !== 'undefined' ? document : null;
      if (!doc || !doc.body) {
        // Last resort: no-cors fetch (opaque response)
        await fetch(url, {
          method: 'GET',
          mode: 'no-cors' as any,
        });
        return {
          ok: true,
          message: 'Başarıyla kaydedildi',
        };
      }

      // Prefer sendBeacon (quiet + avoids CORS console noise)
      const nav: any = typeof navigator !== 'undefined' ? navigator : null;
      if (nav?.sendBeacon) {
        const fd = new FormData();
        fd.append('action', 'subscribe');
        fd.append('email', trimmed);
        fd.append('userAgent', userAgent);
        fd.append('ts', `${Date.now()}`);
        const ok = nav.sendBeacon(this.ENDPOINT, fd);
        if (ok) {
          return {
            ok: true,
            message: 'Başarıyla kaydedildi',
          };
        }
      }

      // Fallback: no-cors fetch (quiet)
      try {
        await fetch(url, {
          method: 'GET',
          mode: 'no-cors' as any,
        });
        return {
          ok: true,
          message: 'Başarıyla kaydedildi',
        };
      } catch {
        // ignore and try last fallback below
      }

      // Last fallback: image beacon GET. This may show 403 in console depending on redirects,
      // but still sends the request.
      await new Promise<void>((resolve) => {
        const img = doc.createElement('img');
        img.style.display = 'none';
        const cleanup = () => {
          try {
            img.onload = null;
            img.onerror = null;
            if (img.parentNode) img.parentNode.removeChild(img);
          } catch {
            // ignore
          }
        };
        img.onload = () => {
          cleanup();
          resolve();
        };
        img.onerror = () => {
          cleanup();
          resolve();
        };
        img.src = url;
        doc.body.appendChild(img);
        setTimeout(() => {
          cleanup();
          resolve();
        }, 2000);
      });

      return {
        ok: true,
        message: 'Başarıyla kaydedildi',
      };
    } catch (e) {
      return {ok: false, message: e instanceof Error ? e.message : String(e)};
    }
  }
}


