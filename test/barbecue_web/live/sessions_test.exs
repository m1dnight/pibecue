defmodule BarbecueWeb.SessionsTest do
  use ExUnit.Case, async: true

  alias BarbecueWeb.Sessions

  describe "format_time/1" do
    # Real DateTimes should be displayed in YYYY-MM-DD HH:MM format
    # (no seconds), so the table is compact and aligned.
    test "formats a UTC DateTime in UTC when timezone is Etc/UTC" do
      assert Sessions.format_time(~U[2026-04-30 18:31:42Z], "Etc/UTC") == "2026-04-30 18:31"
    end

    # The display must shift to the user's IANA timezone — Brussels is
    # UTC+2 in late April (CEST).
    test "shifts a UTC DateTime into the supplied IANA timezone" do
      assert Sessions.format_time(~U[2026-04-30 18:31:42Z], "Europe/Brussels") ==
               "2026-04-30 20:31"
    end

    # Sessions without measurements have nil times; show an em-dash so the
    # table cell isn't empty (timezone is irrelevant).
    test "renders nil as an em-dash regardless of timezone" do
      assert Sessions.format_time(nil, "Etc/UTC") == "—"
    end
  end

  describe "format_duration/1" do
    # Tiny durations show only seconds.
    test "renders sub-minute durations in seconds only" do
      assert Sessions.format_duration(0) == "0s"
      assert Sessions.format_duration(45) == "45s"
    end

    # Durations spanning whole minutes drop the leading 0h.
    test "renders sub-hour durations as minutes + seconds" do
      assert Sessions.format_duration(125) == "2m 5s"
    end

    # Multi-hour durations include hours.
    test "renders multi-hour durations as hours + minutes + seconds" do
      assert Sessions.format_duration(3725) == "1h 2m 5s"
    end

    # Sessions without measurements have nil duration; show an em-dash to
    # match the time formatter's behavior.
    test "renders nil as an em-dash" do
      assert Sessions.format_duration(nil) == "—"
    end
  end
end
