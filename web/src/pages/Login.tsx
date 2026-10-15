import { useState, type FormEvent } from "react";
import { RespondaApiError } from "../api/respondaApi";
import { Icon } from "../components/Icon";
import { useBackendHealth } from "../hooks/useBackendHealth";
import operationCenterPhoto from "../assets/mdrrmo-operation-center.png";
import respondaLogo from "../assets/responda-logo.png";

export function Login({
  onLogin,
}: {
  onLogin: (email: string, password: string) => Promise<void>;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const { connection, refresh } = useBackendHealth();

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError("");
    try {
      await onLogin(email, password);
    } catch (reason) {
      if (reason instanceof RespondaApiError) {
        if (reason.status === 429) {
          setError("Too many login attempts. Please wait before trying again.");
        } else if (reason.status === 401) {
          setError("The email or password is incorrect.");
        } else {
          setError(reason.message);
        }
      } else {
        setError("Unable to reach RESPONDA. Check that the backend is running.");
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="relative flex min-h-screen overflow-hidden bg-[#f7f4f5] max-[900px]:flex-col">
      <section className="relative flex min-h-screen w-[46%] flex-col overflow-hidden bg-deep px-[clamp(32px,5vw,78px)] py-[clamp(32px,6vh,68px)] text-white max-[900px]:min-h-[330px] max-[900px]:w-full max-[900px]:px-7 max-[900px]:py-7 max-[560px]:min-h-[280px]">
        <img
          src={operationCenterPhoto}
          alt=""
          aria-hidden="true"
          className="absolute inset-0 size-full object-cover object-[56%_center] min-[901px]:translate-y-[4%] min-[901px]:scale-[1.28]"
        />
        <div className="absolute inset-0 bg-[#3e0711]/65" />
        <div className="absolute -left-24 top-[18%] size-[360px] rounded-full bg-[#9d344522] blur-2xl max-[900px]:-left-12 max-[900px]:size-48 max-[560px]:-left-8 max-[560px]:size-36" />
        <div className="absolute -bottom-48 -right-24 size-[480px] rounded-full border-[80px] border-[#7f263455] max-[900px]:-bottom-24 max-[900px]:-right-12 max-[900px]:size-64 max-[900px]:border-[44px] max-[560px]:-bottom-16 max-[560px]:-right-8 max-[560px]:size-44 max-[560px]:border-[30px]" />

        <div className="relative z-10 flex items-center gap-3.5">
          <span className="grid size-14 place-items-center rounded-[18px] bg-white p-2 shadow-[0_14px_36px_rgba(0,0,0,.2)]">
            <img
              src={respondaLogo}
              alt="RESPONDA logo"
              className="size-full object-contain"
            />
          </span>
          <div>
            <b className="block text-xl tracking-[.04em]">RESPONDA</b>
            <span className="mt-0.5 block text-[10px] font-semibold tracking-[.16em] text-[#d7aeb5]">
              MDRRMO PANTUKAN
            </span>
          </div>
        </div>

        <div className="relative z-10 flex max-w-[520px] flex-1 flex-col justify-center min-[901px]:-translate-y-32 max-[900px]:mt-6">
          <h1 className="m-0 max-w-[500px] text-[clamp(34px,4.4vw,64px)] font-semibold leading-[1.03] tracking-[-.045em]">
            Ready when every second matters.
          </h1>
          <p className="mt-6 max-w-[460px] text-[13px] leading-6 text-[#d7bfc4] max-[900px]:mb-0 max-[560px]:mt-3 max-[560px]:text-[11px] max-[560px]:leading-5">
            A protected workspace for validating reports, coordinating response
            teams, and monitoring incidents across Pantukan.
          </p>
        </div>
      </section>

      <section className="relative flex min-h-screen flex-1 items-center justify-center px-6 py-10 max-[900px]:min-h-0 max-[900px]:py-12 max-[560px]:px-4">
        <div className="w-full max-w-[430px]">
          <div className="mb-9 flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold tracking-[.16em] text-maroon">
                STAFF PORTAL
              </span>
              <h2 className="mb-2 mt-2 text-[30px] tracking-[-.035em] text-[#27191c]">
                Welcome back
              </h2>
              <p className="m-0 text-[12px] leading-5 text-muted">
                Sign in with your authorized MDRRMO account.
              </p>
            </div>
          </div>

          <form className="grid gap-5" onSubmit={submit} noValidate>
            <label className="grid gap-2 text-[11px] font-semibold text-[#3a2b2e]">
              Email address
              <span className="flex h-12 items-center gap-3 rounded-[13px] border border-[#ddd5d7] bg-white px-3.5 text-muted shadow-[0_2px_7px_rgba(65,24,34,.03)] transition focus-within:border-maroon focus-within:shadow-[0_0_0_4px_rgba(122,31,43,.08)]">
                <Icon name="mail" size={17} />
                <input
                  className="h-full min-w-0 flex-1 border-0 bg-transparent text-[12px] text-[#27191c] outline-0 placeholder:text-[#a79ea0]"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="name@pantukan.gov.ph"
                  autoComplete="username"
                  autoCapitalize="none"
                  spellCheck={false}
                  required
                  autoFocus
                />
              </span>
            </label>

            <label className="grid gap-2 text-[11px] font-semibold text-[#3a2b2e]">
              Password
              <span className="flex h-12 items-center gap-3 rounded-[13px] border border-[#ddd5d7] bg-white px-3.5 text-muted shadow-[0_2px_7px_rgba(65,24,34,.03)] transition focus-within:border-maroon focus-within:shadow-[0_0_0_4px_rgba(122,31,43,.08)]">
                <Icon name="lock" size={17} />
                <input
                  className="h-full min-w-0 flex-1 border-0 bg-transparent text-[12px] text-[#27191c] outline-0 placeholder:text-[#a79ea0]"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="Enter your password"
                  autoComplete="current-password"
                  required
                />
                <button
                  type="button"
                  className="grid size-8 place-items-center rounded-lg border-0 bg-transparent text-muted hover:bg-soft-gray hover:text-maroon"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  aria-pressed={showPassword}
                  onClick={() => setShowPassword((visible) => !visible)}
                >
                  <Icon name={showPassword ? "eyeOff" : "eye"} size={17} />
                </button>
              </span>
            </label>

            {error && (
              <div
                className="flex items-start gap-2.5 rounded-[12px] border border-[#f3c8cc] bg-[#fff1f2] px-3.5 py-3 text-[10px] leading-4 text-[#9b2433]"
                role="alert"
                aria-live="polite"
              >
                <Icon name="alert" size={16} />
                <span>{error}</span>
              </div>
            )}

            <button
              className="mt-1 flex h-12 items-center justify-center gap-2 rounded-[13px] border-0 bg-maroon text-[12px] font-bold text-white shadow-[0_12px_28px_rgba(84,19,29,.2)] transition hover:bg-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-maroon disabled:cursor-not-allowed disabled:opacity-60"
              type="submit"
              disabled={submitting || !email.trim() || !password}
            >
              {submitting ? (
                <>
                  <i className="size-4 animate-spin rounded-full border-2 border-white/35 border-t-white" />
                  Verifying account…
                </>
              ) : (
                <>
                  Sign in securely
                  <Icon name="chevron" size={15} />
                </>
              )}
            </button>
          </form>

          <div className="mt-7 flex items-center justify-between gap-3 border-t border-[#e5dee0] pt-5 text-[9px] text-muted">
            <button
              type="button"
              className="flex items-center gap-2 border-0 bg-transparent p-0 text-[9px] text-muted"
              onClick={refresh}
              title="Check backend connection"
            >
              <i
                className={`size-1.5 rounded-full ${connection.status === "connected" ? "bg-status-green" : connection.status === "checking" ? "animate-pulse bg-priority-amber" : "bg-priority-red"}`}
              />
              {connection.status === "connected"
                ? "Secure server connected"
                : connection.status === "checking"
                  ? "Checking server…"
                  : "Server unavailable · Retry"}
            </button>
            <span>Authorized personnel only</span>
          </div>
        </div>
      </section>
    </main>
  );
}
