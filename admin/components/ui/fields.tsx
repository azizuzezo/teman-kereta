import type {
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
  TextareaHTMLAttributes,
} from "react";
import { cn } from "./cn";

const CONTROL =
  "w-full min-h-11 rounded-control border border-line-strong bg-surface px-3 text-sm text-ink placeholder:text-ink-muted disabled:cursor-not-allowed disabled:opacity-60";

type FieldShellProps = {
  label: string;
  htmlFor: string;
  hint?: ReactNode;
  error?: string;
  optional?: boolean;
  className?: string;
  children: ReactNode;
};

/** Visible label + optional hint + inline error around any control. */
export function Field({
  label,
  htmlFor,
  hint,
  error,
  optional,
  className,
  children,
}: FieldShellProps) {
  return (
    <div className={cn("flex min-w-0 flex-col gap-1.5", className)}>
      <label htmlFor={htmlFor} className="text-sm font-semibold text-ink">
        {label}
        {optional && (
          <span className="ml-1 font-normal text-ink-muted">(opsional)</span>
        )}
      </label>
      {children}
      {hint && (
        <p id={`${htmlFor}-hint`} className="text-xs text-ink-muted">
          {hint}
        </p>
      )}
      {error && (
        <p
          id={`${htmlFor}-error`}
          role="alert"
          className="text-xs font-medium text-bad"
        >
          {error}
        </p>
      )}
    </div>
  );
}

type Shared = {
  label: string;
  name: string;
  /** Override when several forms on one page share a field name. */
  id?: string;
  hint?: ReactNode;
  error?: string;
  optional?: boolean;
  fieldClassName?: string;
};

function describedBy(name: string, hint: ReactNode, error?: string) {
  const ids = [hint ? `${name}-hint` : null, error ? `${name}-error` : null]
    .filter(Boolean)
    .join(" ");
  return ids || undefined;
}

export function TextField({
  label,
  name,
  id,
  hint,
  error,
  optional,
  fieldClassName,
  className,
  ...rest
}: Shared & Omit<InputHTMLAttributes<HTMLInputElement>, "name">) {
  return (
    <Field
      label={label}
      htmlFor={id ?? name}
      hint={hint}
      error={error}
      optional={optional}
      className={fieldClassName}
    >
      <input
        id={id ?? name}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id ?? name, hint, error)}
        className={cn(CONTROL, error && "border-bad", className)}
        {...rest}
      />
    </Field>
  );
}

export function SelectField({
  label,
  name,
  id,
  hint,
  error,
  optional,
  fieldClassName,
  className,
  children,
  ...rest
}: Shared & Omit<SelectHTMLAttributes<HTMLSelectElement>, "name">) {
  return (
    <Field
      label={label}
      htmlFor={id ?? name}
      hint={hint}
      error={error}
      optional={optional}
      className={fieldClassName}
    >
      <select
        id={id ?? name}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id ?? name, hint, error)}
        className={cn(CONTROL, "pr-8", error && "border-bad", className)}
        {...rest}
      >
        {children}
      </select>
    </Field>
  );
}

export function TextareaField({
  label,
  name,
  id,
  hint,
  error,
  optional,
  fieldClassName,
  className,
  ...rest
}: Shared & Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, "name">) {
  return (
    <Field
      label={label}
      htmlFor={id ?? name}
      hint={hint}
      error={error}
      optional={optional}
      className={fieldClassName}
    >
      <textarea
        id={id ?? name}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id ?? name, hint, error)}
        className={cn(CONTROL, "py-2.5", error && "border-bad", className)}
        {...rest}
      />
    </Field>
  );
}

export function FileField({
  label,
  name,
  id,
  hint,
  error,
  optional,
  fieldClassName,
  className,
  ...rest
}: Shared & Omit<InputHTMLAttributes<HTMLInputElement>, "name" | "type">) {
  return (
    <Field
      label={label}
      htmlFor={id ?? name}
      hint={hint}
      error={error}
      optional={optional}
      className={fieldClassName}
    >
      <input
        id={id ?? name}
        name={name}
        type="file"
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id ?? name, hint, error)}
        className={cn(
          CONTROL,
          "py-1.5 file:mr-3 file:min-h-8 file:cursor-pointer file:rounded-[10px] file:border-0 file:bg-brand-soft file:px-3 file:text-xs file:font-semibold file:text-brand",
          error && "border-bad",
          className
        )}
        {...rest}
      />
    </Field>
  );
}

export function CheckboxField({
  label,
  name,
  hint,
  className,
  ...rest
}: {
  label: ReactNode;
  name: string;
  hint?: ReactNode;
  className?: string;
} & Omit<InputHTMLAttributes<HTMLInputElement>, "name" | "type">) {
  return (
    <div className={cn("flex min-h-11 items-start gap-3", className)}>
      <input
        id={name}
        name={name}
        type="checkbox"
        className="mt-0.5 size-5 shrink-0 cursor-pointer accent-brand"
        aria-describedby={hint ? `${name}-hint` : undefined}
        {...rest}
      />
      <div className="min-w-0">
        <label
          htmlFor={name}
          className="cursor-pointer text-sm font-semibold text-ink"
        >
          {label}
        </label>
        {hint && (
          <p id={`${name}-hint`} className="text-xs text-ink-muted">
            {hint}
          </p>
        )}
      </div>
    </div>
  );
}
