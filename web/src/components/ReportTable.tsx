import { tone, type Report } from "../data/reports";
import { Badge } from "./ui";
import { Icon } from "./Icon";

export function ReportTable({
  rows,
  onSelect,
  selectedId,
}: {
  rows: Report[];
  onSelect?: (id: string) => void;
  selectedId?: string;
}) {
  return (
    <div className={"min-w-[700px]"}>
      <div
        className={
          "grid min-h-[42px] grid-cols-[90px_1.1fr_1.3fr_100px_110px_70px_24px] items-center gap-2 border-b border-[#f0f0f1] px-2 text-[10px] [&>strong]:text-maroon h-7 min-h-7 rounded-[9px] border-0 bg-soft-gray text-[8px] font-bold text-muted"
        }
      >
        <span>REFERENCE</span>
        <span>INCIDENT</span>
        <span>LOCATION</span>
        <span>PRIORITY</span>
        <span>STATUS</span>
        <span>REPORTED</span>
        <span />
      </div>
      {rows.map((r) => (
        <div
          className={`grid min-h-[42px] grid-cols-[90px_1.1fr_1.3fr_100px_110px_70px_24px] items-center gap-2 border-b border-[#f0f0f1] px-2 text-[10px] [&>strong]:text-maroon ${onSelect ? "cursor-pointer rounded-[9px] outline-0 transition-[background,box-shadow] hover:bg-[#faf5f6] focus-visible:shadow-[inset_0_0_0_2px_#7a1f2b]" : ""} ${selectedId === r.id ? "bg-blush shadow-[inset_3px_0_0_#7a1f2b]" : ""}`}
          key={r.id}
          role={onSelect ? "button" : undefined}
          tabIndex={onSelect ? 0 : undefined}
          onClick={() => onSelect?.(r.id)}
          onKeyDown={(e) => {
            if (onSelect && (e.key === "Enter" || e.key === " ")) {
              e.preventDefault();
              onSelect(r.id);
            }
          }}
        >
          <strong title={r.id}>{r.reference}</strong>
          <span>{r.incident}</span>
          <span className="grid gap-0.5 text-muted">
            <span>{r.location}</span>
            <small className="text-[8px] text-maroon">
              {r.barangay
                ? `Barangay ${r.barangay}`
                : "Barangay not determined"}
            </small>
          </span>
          <Badge tone={tone(r.priority)}>{r.priority}</Badge>
          <Badge tone={tone(r.status)}>{r.status}</Badge>
          <span className={"text-muted"}>{r.time}</span>
          {onSelect ? <Icon name="chevron" size={15} /> : <span />}
        </div>
      ))}
    </div>
  );
}
