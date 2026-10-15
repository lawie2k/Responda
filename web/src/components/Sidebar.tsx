import type { Page } from "../types";
import { groups, pageInfo } from "../config/navigation";
import { Icon } from "./Icon";
import respondaLogo from "../assets/responda-logo.png";

export function Sidebar({
  page,
  go,
  open,
  close,
}: {
  page: Page;
  go: (p: Page) => void;
  open: boolean;
  close: () => void;
}) {
  return (
    <>
      {open && (
        <button
          aria-label="Close navigation"
          className="fixed inset-0 z-[110] hidden border-0 bg-[#23090f66] backdrop-blur-[2px] max-[1100px]:block"
          onClick={close}
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
            onClick={close}
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
      <div
        className={
          "flex h-[78px] items-center gap-[9px] rounded-[14px] bg-deep-2 p-[11px] [&>span]:grid [&>span]:size-[38px] [&>span]:place-items-center [&>span]:rounded-full [&>span]:bg-blush [&>span]:text-[11px] [&>span]:font-bold [&>span]:text-maroon [&>div]:flex-1 [&_b]:block [&_b]:text-[11px] [&_small]:mt-[3px] [&_small]:block [&_small]:text-[9px] [&_small]:text-[#d9abb3]"
        }
      >
        <span>MS</span>
        <div>
          <b>Maria Santos</b>
          <small>MDRRMO Admin</small>
        </div>
        <Icon name="chevron" />
      </div>
      </aside>
    </>
  );
}
