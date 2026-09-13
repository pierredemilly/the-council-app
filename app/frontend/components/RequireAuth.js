import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "~/lib/auth";
import { t } from "~/i18n";

export default function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return <div className="p-8 text-gray-500">{t("common.loading")}</div>;
  }
  if (!user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return children;
}
