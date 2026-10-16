import type { ReactNode } from "react";
import type { IconName } from "../types";
import { Icon } from "./Icon";

const badgeToneClasses: Record<string, string> = {
  maroon: "bg-blush text-maroon",
  red: "bg-red-soft text-priority-red",
  orange: "bg-orange-soft text-priority-orange",
  amber: "bg-amber-soft text-priority-amber",
  green: "bg-green-soft text-status-green",
  blue: "bg-blue-soft text-status-blue",
};

const buttonVariantClasses = {
  primary: "border border-maroon bg-maroon text-white hover:border-deep hover:bg-deep",
  secondary:
    "border border-[#d9d3d1] bg-white text-[#352b2d] hover:border-maroon hover:text-maroon",
  danger:
    "border border-[#efc7c4] bg-white text-priority-red hover:bg-red-soft",
};

export function Badge({
  children,
  tone = "maroon",
  dot = true,
}: {
  children: ReactNode;
  tone?: string;
  dot?: boolean;
}) {
  return (
    <span
      className={`inline-flex min-h-[22px] items-center gap-1.5 whitespace-nowrap rounded-[5px] px-2 py-1 text-[8px] font-bold tracking-[.015em] [&_i]:size-[5px] [&_i]:rounded-full [&_i]:bg-current ${badgeToneClasses[tone] ?? badgeToneClasses.maroon}`}
    >
      {dot && <i />}
      {children}
    </span>
  );
}
export function Button({
  children,
  icon,
  variant = "primary",
  onClick,
  disabled = false,
}: {
  children: ReactNode;
  icon?: IconName;
  variant?: "primary" | "secondary" | "danger";
  onClick?: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      className={`button inline-flex min-h-10 items-center justify-center gap-[7px] whitespace-nowrap rounded-[7px] px-4 text-[11px] font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-45 ${buttonVariantClasses[variant]}`}
      disabled={disabled}
      onClick={onClick}
    >
      {icon && <Icon name={icon} size={16} />}
      <span>{children}</span>
    </button>
  );
}
export function Card({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`card min-w-0 rounded-[10px] border border-[#dedad8] bg-white px-4 py-[15px] ${className}`}
    >
      {children}
    </section>
  );
}
export function SectionHead({
  title,
  subtitle,
  action,
  onAction,
}: {
  title: string;
  subtitle?: string;
  action?: string;
  onAction?: () => void;
}) {
  return (
    <div
      className={
        "section-head mb-3 flex min-h-[40px] items-center justify-between gap-[10px] border-b border-[#ece8e6] pb-3 [&_h3]:m-0 [&_h3]:text-[14px] [&_h3]:font-semibold [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted [&>button]:flex [&>button]:h-8 [&>button]:items-center [&>button]:gap-[5px] [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-0 [&>button]:text-[9px] [&>button]:font-semibold [&>button]:text-maroon"
      }
    >
      <div>
        <h3>{title}</h3>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {action && (
        <button onClick={onAction}>
          {action}
          <Icon name="chevron" size={13} />
        </button>
      )}
    </div>
  );
}
export function PageTitle({
  title,
  subtitle,
  action,
  onAction,
  actionDisabled = false,
}: {
  title: string;
  subtitle: string;
  action?: string;
  onAction?: () => void;
  actionDisabled?: boolean;
}) {
  return (
    <div
      className={
        "flex min-h-[68px] items-center justify-between border-b border-[#dcd7d4] pb-4 max-[650px]:flex-col max-[650px]:items-start max-[650px]:gap-3 [&>div]:min-w-0 [&_h2]:m-0 [&_h2]:text-[24px] [&_h2]:font-semibold [&_h2]:tracking-[-.025em] max-[650px]:[&_h2]:text-[20px] [&_p]:mb-0 [&_p]:mt-1.5 [&_p]:text-[10px] [&_p]:text-muted"
      }
    >
      <div>
        <h2>{title}</h2>
        <p>{subtitle}</p>
      </div>
      {action && (
        <Button
          icon={action.includes("Export") ? "download" : "plus"}
          onClick={onAction}
          disabled={actionDisabled}
        >
          {action}
        </Button>
      )}
    </div>
  );
}
export function Metric({
  icon,
  title,
  value,
  sub,
  tone,
}: {
  icon: IconName;
  title: string;
  value: string;
  sub: string;
  tone: string;
}) {
  return (
    <Card
      className={`metric-card flex h-[112px] flex-col justify-between border-l-[3px] ${tone === "maroon" ? "border-l-maroon" : "border-l-[#d8d3d0]"}`}
    >
      <div className="flex items-center justify-between gap-3">
        <span className="block text-[9px] font-bold tracking-[.08em] text-muted">
          {title}
        </span>
        <span className="text-[#81787a]">
          <Icon name={icon} size={17} />
        </span>
      </div>
      <div>
        <b className="block text-[26px] leading-none tracking-[-.035em]">
          {value}
        </b>
        <p className="mb-0 mt-2 text-[9px] text-muted">{sub}</p>
      </div>
    </Card>
  );
}
export function Switch({
  value,
  onChange,
  ariaLabel,
}: {
  value: boolean;
  onChange: () => void;
  ariaLabel?: string;
}) {
  return (
    <button
      aria-label={ariaLabel}
      aria-pressed={value}
      className={`h-[21px] w-9 rounded-[20px] border-0 p-0.5 [&_i]:block [&_i]:size-[17px] [&_i]:rounded-full [&_i]:bg-white [&_i]:transition-transform ${value ? "bg-maroon [&_i]:translate-x-[15px]" : "bg-[#d5d5d9]"}`}
      onClick={onChange}
    >
      <i />
    </button>
  );
}

export function SelectField({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: Array<string | { label: string; value: string }>;
  onChange: (value: string) => void;
}) {
  return (
    <label
      className={
        "relative flex h-[38px] min-w-[145px] items-center text-muted max-[650px]:shrink-0 max-[650px]:min-w-[150px] [&_select]:h-full [&_select]:w-full [&_select]:cursor-pointer [&_select]:appearance-none [&_select]:rounded-[7px] [&_select]:border [&_select]:border-[#d9d5d2] [&_select]:bg-white [&_select]:py-0 [&_select]:pl-[10px] [&_select]:pr-[31px] [&_select]:text-[9px] [&_select]:text-muted [&_select]:outline-0 focus-within:[&_select]:border-maroon focus-within:[&_select]:shadow-[0_0_0_3px_rgba(122,31,43,.08)] [&>.icon]:pointer-events-none [&>.icon]:absolute [&>.icon]:right-[9px] [&>.icon]:rotate-90"
      }
    >
      <select
        aria-label={label}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      >
        <option value="">{label}</option>
        {options.map((option) => (
          <option
            value={typeof option === "string" ? option : option.value}
            key={typeof option === "string" ? option : option.value}
          >
            {typeof option === "string" ? option : option.label}
          </option>
        ))}
      </select>
      <Icon name="chevron" size={13} />
    </label>
  );
}
