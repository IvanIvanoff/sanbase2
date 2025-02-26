defmodule Sanbase.DateTimeUtilsTest do
  use Sanbase.DataCase, async: true

  alias Sanbase.DateTimeUtils

  test "#str_to_sec/1" do
    assert DateTimeUtils.str_to_sec("10000000000ns") == 10
    assert DateTimeUtils.str_to_sec("100s") == 100
    assert DateTimeUtils.str_to_sec("1m") == 60
    assert DateTimeUtils.str_to_sec("1h") == 3600
    assert DateTimeUtils.str_to_sec("1d") == 86_400
    assert DateTimeUtils.str_to_sec("1w") == 604_800

    assert_raise CaseClauseError, fn ->
      DateTimeUtils.str_to_sec("100") == 100
    end

    assert_raise CaseClauseError, fn ->
      DateTimeUtils.str_to_sec("1dd") == 100
    end
  end

  test "seconds after" do
    datetime1 = DateTime.from_naive!(~N[2017-05-13 21:45:00], "Etc/UTC")
    datetime2 = DateTime.from_naive!(~N[2017-05-13 21:45:37], "Etc/UTC")

    assert DateTime.compare(
             DateTimeUtils.seconds_after(37, datetime1),
             datetime2
           ) == :eq
  end

  test "seconds ago" do
    datetime1 = DateTime.from_naive!(~N[2017-05-13 21:45:00], "Etc/UTC")
    datetime2 = DateTime.from_naive!(~N[2017-05-13 21:45:37], "Etc/UTC")

    assert DateTime.compare(
             DateTimeUtils.seconds_ago(37, datetime2),
             datetime1
           ) == :eq
  end

  test "start of day" do
    datetime1 = DateTime.from_naive!(~N[2014-10-02 10:29:10], "Etc/UTC")
    datetime2 = DateTime.from_naive!(~N[2014-10-02 00:00:00], "Etc/UTC")

    assert DateTime.compare(
             DateTimeUtils.start_of_day(datetime1),
             datetime2
           )
  end
end
