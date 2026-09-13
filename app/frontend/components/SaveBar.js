import { buttonClass } from "~/components/AuthLayout";
import FormError from "~/components/FormError";
import { t } from "~/i18n";

export default function SaveBar({ saving, saved, error, dirty }) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <button
        type="submit"
        className={`${buttonClass} sm:w-auto`}
        disabled={saving || !dirty}
      >
        {saving ? t("common.saving") : t("common.save")}
      </button>
      {saved && !dirty && (
        <span className="text-sm text-green-700">{t("admin.saved")}</span>
      )}
      <FormError message={error} />
    </div>
  );
}
