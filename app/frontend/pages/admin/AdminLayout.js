import { NavLink, Outlet, Link } from "react-router-dom";
import {
  ArrowRightOnRectangleIcon,
  Cog6ToothIcon,
  UserGroupIcon,
} from "@heroicons/react/24/outline";
import { useAuth } from "~/lib/auth";
import { t } from "~/i18n";

const linkClass = ({ isActive }) =>
  `flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium ${
    isActive
      ? "bg-indigo-50 text-indigo-700"
      : "text-gray-700 hover:bg-gray-100"
  }`;

export default function AdminLayout() {
  const { user, signOut } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-3">
          <Link to="/" className="text-lg font-semibold text-gray-900">
            {t("app.name")}
          </Link>
          <nav className="flex gap-1">
            <NavLink to="/admin" end className={linkClass}>
              <Cog6ToothIcon className="h-5 w-5" />
              {t("admin.nav.settings")}
            </NavLink>
            <NavLink to="/admin/characters" className={linkClass}>
              <UserGroupIcon className="h-5 w-5" />
              {t("admin.nav.characters")}
            </NavLink>
          </nav>
          <div className="flex items-center gap-3 text-sm text-gray-600">
            <span className="hidden sm:inline">{user.email}</span>
            <button
              className="flex items-center gap-1 rounded-md px-2 py-1 hover:bg-gray-100"
              onClick={signOut}
            >
              <ArrowRightOnRectangleIcon className="h-5 w-5" />
              {t("admin.sign_out")}
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-8">
        <Outlet />
      </main>
    </div>
  );
}
