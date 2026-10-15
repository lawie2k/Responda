import { useEffect, useRef, useState } from "react";
import type { AdminUser } from "../api/respondaApi";
import type { Page } from "../types";
import { groups, pageInfo } from "../config/navigation";
import { Icon } from "./Icon";
import respondaLogo from "../assets/responda-logo.png";

export function Sidebar({
  page,
  go,
  open,
  close,
  user,
  onLogout,
}: {
  page: Page;
  go: (p: Page) => void;
  open: boolean;
  close: () => void;
  user: AdminUser;
  onLogout: () => Promise<void>;
}) {
  const [accountMenuOpen, setAccountMenuOpen] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);
  const [logoutError, setLogoutError] = useState("");
  const accountMenuRef = useRef<HTMLDivElement>(null);
  const initials =
    user.full_name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || user.email.slice(0, 2).toUpperCase();
  const roleLabel =
    user.role === "admin"
      ? "Administrator"
      : user.role.charAt(0).toUpperCase() + user.role.slice(1);

  useEffect(() => {
    const closeAccountMenu = (event: MouseEvent) => {
      if (!accountMenuRef.current?.contains(event.target as Node)) {
        setAccountMenuOpen(false);
      }
    };
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setAccountMenuOpen(false);
    };
    document.addEventListener("mousedown", closeAccountMenu);
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("mousedown", closeAccountMenu);
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, []);

  const logout = async () => {
    if (loggingOut) return;
    setLoggingOut(true);
    setLogoutError("");
    try {
      await onLogout();
    } catch {
      setLogoutError("Could not sign out. Check the server and try again.");
      setLoggingOut(false);
    }
  };

  return (
    <>
      {open && (
        <button
          aria-label="Close navigation"
          className="fixed inset-0 z-[110] hidden border-0 bg-[#23090f66] backdrop-blur-[2px] max-[1100px]:block"
          onClick={() => {
            setAccountMenuOpen(false);
            close();
          }}
        />
      )}
      <aside
        className={`fixed inset-y-0 left-0 z-[120] flex w-60 flex-col justify-between bg-deep p-5 text-white transition-transform max-[1100px]:-translate-x-full max-[1100px]:shadow-[20px_0_45px_#28050c40] ${open ? "max-[1100px]:translate-x-0" : ""}`}
      >
      <div>
        <div
          className={
            "flex h-[62px] items-center gap-3 [&>span]:grid [&>span]:size-[46px] [&>span]:shrink-0 [&>span]:place-items-center [&>span]:overflow-hidden [&>span]:rounded-[15px] [&>span]:bg-white [&>span]:p-1.5 [&>span>img]:size-full [&>span>img]:object-contain [&_b]:block [&_b]:text-[17px] [&_small]:mt-1 [&_small]:block [&_small]:text-[9px] [&_small]:font-semibold [&_small]:text-[#d9abb3]"
          }
        >
          <span>
            <img src={respondaLogo} alt="RESPONDA logo" />
          </span>
          <div>
            <b>RESPONDA</b>
            <small>MDRRMO PANTUKAN</small>
          </div>
          <button
            aria-label="Close navigation"
            className={
              "ml-auto hidden border-0 bg-transparent text-[26px] text-white max-[1100px]:block"
            }
            onClick={() => {
              setAccountMenuOpen(false);
              close();
            }}
          >
            ×
          </button>
        </div>
        <div
          className={
            "my-[10px] mb-[18px] flex h-[34px] items-center gap-2 rounded-[11px] bg-deep-2 px-[10px] text-[9px] font-bold text-[#bfefd2] [&>i]:size-[7px] [&>i]:rounded-full [&>i]:bg-[#56d98c] [&>span]:ml-auto [&>span]:text-[8px] [&>span]:font-normal [&>span]:text-[#d9abb3]"
          }
        >
          <i />
          SYSTEM ONLINE <span>Updated now</span>
        </div>
        <nav>
          {groups.map((g) => (
            <div
              className={
                "mb-[14px] grid gap-[5px] [&>label]:px-1 [&>label]:text-[9px] [&>label]:font-bold [&>label]:tracking-[.08em] [&>label]:text-[#b67d87] [&>button]:flex [&>button]:h-11 [&>button]:items-center [&>button]:gap-[11px] [&>button]:rounded-xl [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-3 [&>button]:text-left [&>button]:text-xs [&>button]:font-medium [&>button]:text-[#eaced3] [&>button:hover]:bg-[#6b1925] [&>button:hover]:text-white [&>button.active]:bg-[#6b1925] [&>button.active]:text-white [&>button>span]:flex-1 [&>button>b]:min-w-7 [&>button>b]:rounded-xl [&>button>b]:bg-white [&>button>b]:p-[5px] [&>button>b]:text-center [&>button>b]:text-[9px] [&>button>b]:text-maroon"
              }
              key={g.label}
            >
              <label>{g.label}</label>
              {g.items.map(([x, icon, count]) => (
                <button
                  className={page === x ? "active" : ""}
                  title={pageInfo[x][1]}
                  onClick={() => {
                    go(x);
                    setAccountMenuOpen(false);
                    close();
                  }}
                  key={x}
                >
                  <Icon name={icon} />
                  <span>{x}</span>
                  {count && <b>{count}</b>}
                </button>
              ))}
            </div>
          ))}
        </nav>
      </div>
      <div className="relative" ref={accountMenuRef}>
        {logoutError && (
          <p className="mb-2 rounded-[10px] bg-[#791f2d] px-2.5 py-2 text-[8px] leading-3 text-[#ffe8ec]" role="alert">
            {logoutError}
          </p>
        )}
        {accountMenuOpen && (
          <div
            id="sidebar-account-menu"
            role="menu"
            className="absolute bottom-[calc(100%+10px)] left-0 z-30 w-full overflow-hidden rounded-[14px] border border-[#eadde0] bg-white p-2 text-[#27191c] shadow-[0_18px_45px_rgba(20,3,8,.28)]"
          >
            <div className="rounded-[11px] bg-soft-gray px-3 py-2.5">
              <span className="mb-1 flex items-center gap-1.5 text-[8px] font-bold tracking-[.06em] text-status-green">
                <i className="size-1.5 rounded-full bg-status-green" />
                SIGNED IN SECURELY
              </span>
              <b className="block truncate text-[11px]">{user.full_name}</b>
              <span className="mt-1 block truncate text-[8px] text-muted">
                {user.email}
              </span>
              <span className="mt-2 inline-flex rounded-full bg-white px-2 py-1 text-[8px] font-semibold text-maroon">
                {roleLabel}
              </span>
            </div>
            <button
              type="button"
              role="menuitem"
              className="mt-2 flex h-10 w-full items-center gap-2 rounded-[10px] border-0 bg-transparent px-3 text-left text-[10px] font-semibold text-priority-red hover:bg-red-soft disabled:cursor-wait disabled:opacity-50"
              disabled={loggingOut}
              onClick={() => void logout()}
            >
              {loggingOut ? (
                <i className="size-4 animate-spin rounded-full border-2 border-priority-red/25 border-t-priority-red" />
              ) : (
                <Icon name="logout" size={16} />
              )}
              <span>{loggingOut ? "Signing out…" : "Sign out"}</span>
            </button>
          </div>
        )}
        <button
          type="button"
          className="flex min-h-[78px] w-full items-center gap-[9px] rounded-[14px] border border-transparent bg-deep-2 p-[11px] text-left text-white transition hover:border-[#9b4d5a] hover:bg-[#641724] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#e8b9c1] [&>.avatar]:grid [&>.avatar]:size-[38px] [&>.avatar]:shrink-0 [&>.avatar]:place-items-center [&>.avatar]:rounded-full [&>.avatar]:bg-blush [&>.avatar]:text-[11px] [&>.avatar]:font-bold [&>.avatar]:text-maroon [&>.copy]:min-w-0 [&>.copy]:flex-1 [&_b]:block [&_b]:truncate [&_b]:text-[11px] [&_small]:mt-[3px] [&_small]:block [&_small]:truncate [&_small]:text-[9px] [&_small]:text-[#d9abb3]"
          aria-haspopup="menu"
          aria-expanded={accountMenuOpen}
          aria-controls="sidebar-account-menu"
          onClick={() => {
            setLogoutError("");
            setAccountMenuOpen((current) => !current);
          }}
        >
          <span className="avatar">{initials}</span>
          <span className="copy">
            <b>{user.full_name}</b>
            <small>{roleLabel}</small>
          </span>
          <span
            aria-hidden="true"
            className={`pointer-events-none grid size-7 shrink-0 place-items-center rounded-[9px] text-[#d9abb3] transition-transform ${accountMenuOpen ? "rotate-[-90deg]" : "rotate-90"}`}
          >
            <Icon name="chevron" size={15} />
          </span>
        </button>
      </div>
      </aside>
    </>
  );
}
