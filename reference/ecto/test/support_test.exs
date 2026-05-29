defmodule SupportTest do
  use Bench.DataCase, async: false

  describe "create_ticket/2" do
    test "valid attrs create an open ticket" do
      actor = user()
      assert {:ok, t} = Support.create_ticket(%{subject: "Cannot log in", body: "500 error"}, actor: actor)
      assert t.status == :open
      assert t.priority == :medium
      assert {:ok, fetched} = Support.get_ticket(t.id)
      assert fetched.subject == "Cannot log in"
    end

    test "subject shorter than 5 chars is rejected and not persisted" do
      actor = user()
      assert {:error, _} = Support.create_ticket(%{subject: "no", body: "x"}, actor: actor)
      assert {:ok, list} = Support.list_tickets()
      assert list == []
    end

    test "invalid priority is rejected" do
      actor = user()
      assert {:error, _} =
               Support.create_ticket(%{subject: "valid subject", body: "x", priority: :urgent}, actor: actor)
    end
  end

  describe "list/get" do
    test "list filters by status" do
      a = user()
      {:ok, _} = Support.create_ticket(%{subject: "first ticket", body: "b"}, actor: a)
      assert {:ok, [_]} = Support.list_tickets(status: :open)
      assert {:ok, []} = Support.list_tickets(status: :closed)
    end

    test "get_ticket on unknown id returns not_found" do
      assert {:error, :not_found} = Support.get_ticket("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "add_comment/3" do
    test "valid comment attaches to ticket" do
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "needs detail", body: "b"}, actor: a)
      assert {:ok, _c} = Support.add_comment(t.id, %{body: "more info"}, actor: a)
      assert {:ok, fetched} = Support.get_ticket(t.id)
      assert length(fetched.comments) == 1
    end

    test "empty comment body is rejected" do
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "needs detail", body: "b"}, actor: a)
      assert {:error, _} = Support.add_comment(t.id, %{body: ""}, actor: a)
    end
  end

  describe "close_ticket/2 authorization + transitions" do
    test "assignee can close an open ticket" do
      assn = assignee()
      {:ok, t} = Support.create_ticket(%{subject: "assign to me", body: "b", assignee_id: assn.id}, actor: assn)
      assert {:ok, closed} = Support.close_ticket(t.id, actor: assn)
      assert closed.status == :closed
    end

    test "admin can close any ticket" do
      a = user()
      adm = admin()
      {:ok, t} = Support.create_ticket(%{subject: "admin closes", body: "b"}, actor: a)
      assert {:ok, closed} = Support.close_ticket(t.id, actor: adm)
      assert closed.status == :closed
    end

    test "unrelated non-admin cannot close; status unchanged" do
      a = user()
      other = user()
      {:ok, t} = Support.create_ticket(%{subject: "not yours", body: "b"}, actor: a)
      assert {:error, _} = Support.close_ticket(t.id, actor: other)
      assert {:ok, again} = Support.get_ticket(t.id)
      assert again.status == :open
    end

    test "closing an already-closed ticket is rejected" do
      adm = admin()
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "double close", body: "b"}, actor: a)
      {:ok, _} = Support.close_ticket(t.id, actor: adm)
      assert {:error, _} = Support.close_ticket(t.id, actor: adm)
    end
  end

  describe "reopen_ticket/2" do
    test "admin can reopen a closed ticket" do
      adm = admin()
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "reopen me", body: "b"}, actor: a)
      {:ok, _} = Support.close_ticket(t.id, actor: adm)
      assert {:ok, reopened} = Support.reopen_ticket(t.id, actor: adm)
      assert reopened.status == :open
    end

    test "non-admin cannot reopen; status unchanged" do
      adm = admin()
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "reopen guard", body: "b"}, actor: a)
      {:ok, _} = Support.close_ticket(t.id, actor: adm)
      assert {:error, _} = Support.reopen_ticket(t.id, actor: a)
      assert {:ok, still} = Support.get_ticket(t.id)
      assert still.status == :closed
    end

    test "reopening a non-closed ticket is rejected" do
      a = user()
      {:ok, t} = Support.create_ticket(%{subject: "not closed", body: "b"}, actor: a)
      assert {:error, _} = Support.reopen_ticket(t.id, actor: admin())
    end
  end
end
