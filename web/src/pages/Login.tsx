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
    <main className="grid min-h-screen bg-[#f4f1ef] text-[#251c1e] min-[901px]:grid-cols-[42%_58%]">
      <section className="relative flex min-h-[360px] overflow-hidden bg-deep text-white max-[900px]:min-h-[320px]">
        <img
          src={operationCenterPhoto}
          alt=""
          aria-hidden="true"
          className="absolute inset-0 size-full object-cover object-[56%_center]"
        />
        <div className="absolute inset-0 bg-[#3f0c14]/80" />

        <div className="relative z-10 flex min-h-full w-full flex-col px-[clamp(28px,5vw,72px)] py-[clamp(28px,5vh,54px)] max-[560px]:px-6 max-[560px]:py-6">
          <div className="flex items-center gap-3">
            <img
              src={respondaLogo}
              alt="RESPONDA logo"
              className="size-10 rounded-[10px] bg-white p-1.5"
            />
            <div>
              <b className="block text-[17px] tracking-[.035em]">RESPONDA</b>
              <span className="mt-0.5 block text-[9px] font-semibold tracking-[.16em] text-[#d9bbc0]">
                MDRRMO PANTUKAN
              </span>
            </div>
          </div>

          <div className="mt-14 max-w-[470px] border-l-2 border-white/70 pl-5 max-[560px]:mt-10">
            <span className="text-[9px] font-bold tracking-[.18em] text-[#e2c7cc]">
              MUNICIPAL EMERGENCY OPERATIONS
            </span>
            <h1 className="mb-0 mt-3 text-[clamp(30px,3.5vw,48px)] font-semibold leading-[1.08] tracking-[-.035em]">
              Pantukan emergency operations console
            </h1>
            <p className="mb-0 mt-4 max-w-[420px] text-[12px] leading-6 text-[#e3d2d5] max-[560px]:text-[11px] max-[560px]:leading-5">
              Review incoming reports, verify incidents, and coordinate response
              units from one protected staff workspace.
            </p>
          </div>

          <div className="mt-auto flex items-center justify-between gap-4 border-t border-white/20 pt-4 text-[9px] text-[#d9bbc0]">
            <span>Pantukan, Davao de Oro</span>
            <span>Authorized MDRRMO staff</span>
          </div>
        </div>
      </section>

      <section className="flex min-h-screen items-center justify-center px-[clamp(28px,7vw,112px)] py-12 max-[900px]:min-h-0 max-[560px]:px-5 max-[560px]:py-9">
        <div className="w-full max-w-[410px]">
          <header className="mb-10">
            <span className="text-[9px] font-bold tracking-[.18em] text-maroon">
              AUTHORIZED STAFF ACCESS
            </span>
            <h2 className="mb-3 mt-3 text-[32px] leading-tight tracking-[-.035em] text-[#251c1e] max-[560px]:text-[28px]">
              Sign in to RESPONDA
            </h2>
            <p className="m-0 max-w-[360px] text-[12px] leading-5 text-muted">
              Use your MDRRMO account to open the Pantukan operations dashboard.
            </p>
          </header>

          <form className="grid gap-5" onSubmit={submit} noValidate>
            <label className="grid gap-2 text-[11px] font-semibold text-[#3a2b2e]">
              Email address
              <span className="flex h-12 items-center gap-3 border border-[#d9d1d2] bg-[#fbfaf9] px-3.5 text-muted transition focus-within:border-maroon focus-within:outline focus-within:outline-[3px] focus-within:outline-[#7a1f2b14]">
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
              <span className="flex h-12 items-center gap-3 border border-[#d9d1d2] bg-[#fbfaf9] px-3.5 text-muted transition focus-within:border-maroon focus-within:outline focus-within:outline-[3px] focus-within:outline-[#7a1f2b14]">
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
                  className="grid size-8 place-items-center border-0 bg-transparent text-muted hover:text-maroon"
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
                className="flex items-start gap-2.5 border-l-[3px] border-priority-red bg-[#fff1f2] px-3.5 py-3 text-[10px] leading-4 text-[#9b2433]"
                role="alert"
                aria-live="polite"
              >
                <Icon name="alert" size={16} />
                <span>{error}</span>
              </div>
            )}

            <button
              className="mt-1 flex h-12 items-center justify-center gap-2 border-0 bg-maroon text-[12px] font-bold text-white transition-colors hover:bg-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-maroon disabled:cursor-not-allowed disabled:opacity-55"
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
                  Sign in
                  <Icon name="chevron" size={15} />
                </>
              )}
            </button>
          </form>

          <div className="mt-8 flex items-center justify-between gap-3 border-t border-[#dcd5d6] pt-5 text-[9px] text-muted max-[560px]:items-start">
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
            <span>Staff use only</span>
          </div>
        </div>
      </section>
    </main>
  );
}
